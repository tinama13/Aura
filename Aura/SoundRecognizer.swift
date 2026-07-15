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
    
    private struct PendingDetectionRecording {
        let label: String
        let confidence: Double
        let detectedAt: Date
        let fileURL: URL
        let audioFile: AVAudioFile
        let targetFrameCount: AVAudioFramePosition
        var writtenFrameCount: AVAudioFramePosition
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioBufferLock = NSLock()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var recordingFormat: AVAudioFormat?
    private var recentAudioBuffers: [BufferedAudio] = []
    private var pendingDetectionRecording: PendingDetectionRecording?
    private var currentCandidate: String?
    private var candidateCount = 0
    private var lastDetectionTimes: [String: Date] = [:]
    
    private let detectionRecordingDuration: TimeInterval = 8
    private let minimumConfidence = 0.75
    private let requiredConsecutiveMatches = 1
    private let detectionCooldown: TimeInterval = 6
    
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
            let inputFormat = inputNode.outputFormat(forBus: 0)
            recordingFormat = inputFormat
            
            streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
            try streamAnalyzer?.add(request, withObserver: self)
            
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, time in
                self?.storeRecentAudio(buffer, at: time.sampleTime)
                self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            
            resetDetectionState()
            clearAudioState()
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
        clearAudioState()
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
        startDetectionRecording(label: label, confidence: confidence, detectedAt: Date())
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("AI Analysis failed: \(error.localizedDescription)")
    }
    
    private func resetDetectionState() {
        currentCandidate = nil
        candidateCount = 0
    }
    
    private func canEmitDetection(for label: String) -> Bool {
        audioBufferLock.lock()
        let alreadyRecording = pendingDetectionRecording != nil
        audioBufferLock.unlock()
        
        if alreadyRecording { return false }
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
    
    private func startDetectionRecording(label: String, confidence: Double, detectedAt: Date) {
        guard let format = recordingFormat else { return }
        
        do {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "Aura_Detection_\(sanitizedFileName(label))_\(Int(detectedAt.timeIntervalSince1970)).caf"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            let targetFrameCount = AVAudioFramePosition(detectionRecordingDuration * format.sampleRate)
            var recording = PendingDetectionRecording(
                label: label,
                confidence: confidence,
                detectedAt: detectedAt,
                fileURL: fileURL,
                audioFile: audioFile,
                targetFrameCount: targetFrameCount,
                writtenFrameCount: 0
            )
            
            audioBufferLock.lock()
            for storedAudio in recentAudioBuffers {
                try audioFile.write(from: storedAudio.buffer)
                recording.writtenFrameCount += AVAudioFramePosition(storedAudio.buffer.frameLength)
            }
            pendingDetectionRecording = recording
            audioBufferLock.unlock()
        } catch {
            print("Failed to start detection recording: \(error.localizedDescription)")
        }
    }
    
    private func storeRecentAudio(_ buffer: AVAudioPCMBuffer, at startFramePosition: AVAudioFramePosition) {
        guard let copiedBuffer = copyAudioBuffer(buffer) else { return }
        let endFramePosition = startFramePosition + AVAudioFramePosition(buffer.frameLength)
        let maxStoredFrames = AVAudioFramePosition(detectionRecordingDuration * buffer.format.sampleRate)
        var completedDetection: SoundDetection?
        
        audioBufferLock.lock()
        recentAudioBuffers.append(BufferedAudio(buffer: copiedBuffer, endFramePosition: endFramePosition))
        recentAudioBuffers.removeAll { endFramePosition - $0.endFramePosition > maxStoredFrames }
        
        if var recording = pendingDetectionRecording {
            do {
                try recording.audioFile.write(from: copiedBuffer)
                recording.writtenFrameCount += AVAudioFramePosition(copiedBuffer.frameLength)
                
                if recording.writtenFrameCount >= recording.targetFrameCount {
                    completedDetection = SoundDetection(
                        name: recording.label,
                        confidence: recording.confidence,
                        timestamp: recording.detectedAt,
                        audioFileURL: recording.fileURL
                    )
                    pendingDetectionRecording = nil
                } else {
                    pendingDetectionRecording = recording
                }
            } catch {
                print("Failed to write detection audio: \(error.localizedDescription)")
                pendingDetectionRecording = nil
            }
        }
        audioBufferLock.unlock()
        
        if let completedDetection {
            publish(completedDetection)
        }
    }
    
    private func publish(_ detection: SoundDetection) {
        DispatchQueue.main.async {
            self.detectedSound = detection.name
            self.confidence = detection.confidence
            self.latestDetection = detection
            print("AI Heard: \(detection.name) at \(Int(detection.confidence * 100))%")
        }
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
    
    private func sanitizedFileName(_ label: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return label
            .replacingOccurrences(of: " ", with: "_")
            .components(separatedBy: allowedCharacters.inverted)
            .joined()
    }
    
    private func clearAudioState() {
        audioBufferLock.lock()
        recentAudioBuffers.removeAll()
        pendingDetectionRecording = nil
        audioBufferLock.unlock()
    }
}
