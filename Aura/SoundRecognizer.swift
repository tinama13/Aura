//
//  SoundRecognizer.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI
import Combine
import SoundAnalysis
import CoreML
import AVFoundation

struct SoundDetection: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let confidence: Double
    let timestamp: Date
    let audioFileURL: URL?
}

class SoundRecognizer: NSObject, ObservableObject, SNResultsObserving {
    private struct BufferedAudio {
        let buffer: AVAudioPCMBuffer
        let endFramePosition: AVAudioFramePosition
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioBufferLock = NSLock()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var recentAudioBuffers: [BufferedAudio] = []
    private var currentCandidate: String?
    private var candidateCount = 0
    private var lastDetectionTimes: [String: Date] = [:]
    
    private let recentAudioDuration: TimeInterval = 8
    private let minimumConfidence = 0.90
    private let requiredConsecutiveMatches = 3
    private let detectionCooldown: TimeInterval = 8
    
    @Published var detectedSound: String = "Waiting for sound..."
    @Published var confidence: Double = 0.0
    @Published var latestDetection: SoundDetection?
    
    func startListening() {
        guard !audioEngine.isRunning else { return }
        guard let model = try? AuraSoundDetection(configuration: MLModelConfiguration()) else {
            print("Failed to load the Create ML model.")
            return
        }
        
        let mlModel = model.model
        
        do {
            let request = try SNClassifySoundRequest(mlModel: mlModel)
            request.overlapFactor = 0.5
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            streamAnalyzer = SNAudioStreamAnalyzer(format: recordingFormat)
            try streamAnalyzer?.add(request, withObserver: self)
            
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { [weak self] buffer, time in
                self?.storeRecentAudio(buffer, at: time.sampleTime)
                self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            
            resetDetectionState()
            clearRecentAudio()
            try audioEngine.start()
            print("AI is now actively listening!")
            
        } catch {
            print("Error starting AI: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        streamAnalyzer = nil
        resetDetectionState()
        clearRecentAudio()
        print("AI stopped listening.")
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let bestClassification = result.classifications.first else { return }
        
        let label = bestClassification.identifier
        let confidence = bestClassification.confidence
        
        guard confidence >= minimumConfidence, !isNonActionableLabel(label) else {
            currentCandidate = nil
            candidateCount = 0
            return
        }
        
        if label == currentCandidate {
            candidateCount += 1
        } else {
            currentCandidate = label
            candidateCount = 1
        }
        
        guard candidateCount >= requiredConsecutiveMatches else { return }
        guard canEmitDetection(for: label) else { return }
        
        lastDetectionTimes[label] = Date()
        let detectionTime = Date()
        let audioFileURL = saveRecentAudioClip(for: label, detectedAt: detectionTime)
        
        DispatchQueue.main.async {
            self.detectedSound = label
            self.confidence = confidence
            self.latestDetection = SoundDetection(
                name: label,
                confidence: confidence,
                timestamp: detectionTime,
                audioFileURL: audioFileURL
            )
            print("AI Heard: \(label) at \(Int(confidence * 100))%")
        }
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("AI Analysis failed: \(error.localizedDescription)")
    }
    
    private func resetDetectionState() {
        currentCandidate = nil
        candidateCount = 0
    }
    
    private func canEmitDetection(for label: String) -> Bool {
        guard let lastDetectionTime = lastDetectionTimes[label] else { return true }
        return Date().timeIntervalSince(lastDetectionTime) >= detectionCooldown
    }
    
    private func isNonActionableLabel(_ label: String) -> Bool {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty
            || normalized == "silence"
            || normalized == "background noise"
            || normalized == "unknown"
            || normalized == "other"
    }
    
    private func storeRecentAudio(_ buffer: AVAudioPCMBuffer, at startFramePosition: AVAudioFramePosition) {
        guard let copiedBuffer = copyAudioBuffer(buffer) else { return }
        let endFramePosition = startFramePosition + AVAudioFramePosition(buffer.frameLength)
        let maxStoredFrames = AVAudioFramePosition(recentAudioDuration * buffer.format.sampleRate)
        
        audioBufferLock.lock()
        recentAudioBuffers.append(BufferedAudio(buffer: copiedBuffer, endFramePosition: endFramePosition))
        recentAudioBuffers.removeAll { endFramePosition - $0.endFramePosition > maxStoredFrames }
        audioBufferLock.unlock()
    }
    
    private func copyAudioBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copiedBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copiedBuffer.frameLength = buffer.frameLength
        
        guard let sourceChannels = buffer.floatChannelData,
              let destinationChannels = copiedBuffer.floatChannelData else {
            return nil
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        for channel in 0..<channelCount {
            destinationChannels[channel].update(from: sourceChannels[channel], count: frameLength)
        }
        
        return copiedBuffer
    }
    
    private func saveRecentAudioClip(for label: String, detectedAt date: Date) -> URL? {
        audioBufferLock.lock()
        let buffers = recentAudioBuffers.map(\.buffer)
        audioBufferLock.unlock()
        
        guard let firstBuffer = buffers.first else { return nil }
        
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "Aura_Detection_\(sanitizedFileName(label))_\(Int(date.timeIntervalSince1970)).caf"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: firstBuffer.format.settings)
            
            for buffer in buffers {
                try audioFile.write(from: buffer)
            }
            
            return fileURL
        } catch {
            print("Failed to save detection audio: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func sanitizedFileName(_ label: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return label
            .replacingOccurrences(of: " ", with: "_")
            .components(separatedBy: allowedCharacters.inverted)
            .joined()
    }
    
    private func clearRecentAudio() {
        audioBufferLock.lock()
        recentAudioBuffers.removeAll()
        audioBufferLock.unlock()
    }
}
