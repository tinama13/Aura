//
//  SoundRecognizer.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI
import Combine
import SoundAnalysis
import AVFoundation

struct SoundDetection: Identifiable, Equatable {
    let id: UUID
    let name: String
    let confidence: Double
    let timestamp: Date
    let endedAt: Date
    let timeline: [TimelineNode]
    let audioFileURL: URL?
    
    init(id: UUID = UUID(), name: String, confidence: Double, timestamp: Date, endedAt: Date, timeline: [TimelineNode], audioFileURL: URL?) {
        self.id = id
        self.name = name
        self.confidence = confidence
        self.timestamp = timestamp
        self.endedAt = endedAt
        self.timeline = timeline
        self.audioFileURL = audioFileURL
    }
}

class SoundRecognizer: NSObject, ObservableObject, SNResultsObserving {
    private struct BufferedAudio {
        let buffer: AVAudioPCMBuffer
        let endFramePosition: AVAudioFramePosition
    }
    
    private struct PendingDetectionRecording {
        let id: UUID
        let label: String
        let confidence: Double
        let detectedAt: Date
        let fileURL: URL
        let audioFile: AVAudioFile
        let targetFrameCount: AVAudioFramePosition
        var writtenFrameCount: AVAudioFramePosition
        var lastActiveAt: Date
        var quietingLogged: Bool
        var louderLogged: Bool
        var startLevel: Float?
        var peakLevel: Float
        var timeline: [TimelineNode]
    }
    
    private let audioEngine = AVAudioEngine()
    private let audioBufferLock = NSLock()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    private var silenceSourceNode: AVAudioSourceNode?
    private var recordingFormat: AVAudioFormat?
    private var recentAudioBuffers: [BufferedAudio] = []
    private var pendingDetectionRecording: PendingDetectionRecording?
    private var currentCandidate: String?
    private var candidateCount = 0
    private var lastDetectionTimes: [String: Date] = [:]
    private var listeningStartedAt: Date?
    private var lastAudioBufferReceivedAt: Date?
    private var lastAudioTapLogAt: Date?
    private var lastClassificationLogAt: Date?
    
    private var currentRequest: SNRequest?
    private var systemRequest: SNClassifySoundRequest?
    
    private let detectionRecordingDuration: TimeInterval = 4
    private let minimumConfidence = 0.75
    private let activeSoundConfidence = 0.35
    private let requiredConsecutiveMatches = 1
    private let detectionCooldown: TimeInterval = 6
    
    @Published var detectedSound: String = "Waiting for sound..."
    @Published var confidence: Double = 0.0
    @Published var latestDetection: SoundDetection?
    
    var isActivelyListening: Bool {
        audioEngine.isRunning
    }
    
    var audioEngineNotificationObject: AVAudioEngine {
        audioEngine
    }
    
    var secondsSinceLastAudioBuffer: TimeInterval? {
        guard let lastAudioBufferReceivedAt else { return nil }
        return Date().timeIntervalSince(lastAudioBufferReceivedAt)
    }
    
    var secondsSinceListeningStartedWithoutAudio: TimeInterval? {
        guard audioEngine.isRunning,
              lastAudioBufferReceivedAt == nil,
              let listeningStartedAt else {
            return nil
        }
        return Date().timeIntervalSince(listeningStartedAt)
    }
    
    @discardableResult
    func startListening() -> Bool {
        if audioEngine.isRunning {
            return true
        }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        streamAnalyzer = nil
        currentRequest = nil
        
        resetDetectionState()
        clearAudioState()
        listeningStartedAt = nil
        lastAudioBufferReceivedAt = nil
        lastAudioTapLogAt = nil
        lastClassificationLogAt = nil
        
        do {
            let request = try systemClassificationRequest()
            print("Starting SoundAnalysis with Apple's built-in System Classifier")
            
            try configureAudioSessionForContinuousListening()
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
                print("Aura audio input format is invalid (sample rate or channels are 0). Aborting start.")
                return false
            }
            
            recordingFormat = inputFormat
            installSilentOutputNode(sampleRate: inputFormat.sampleRate)
            
            streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
            try streamAnalyzer?.add(request, withObserver: self)
            currentRequest = request
            
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, time in
                let now = Date()
                self?.lastAudioBufferReceivedAt = now
                self?.logAudioTapIfNeeded(at: now)
                self?.storeRecentAudio(buffer, at: time.sampleTime)
                
                self?.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            
            resetDetectionState()
            clearAudioState()
            audioEngine.prepare()
            try audioEngine.start()
            listeningStartedAt = Date()
            
            print("AI is now actively listening!")
            return true
            
        } catch {
            print("Error starting AI: \(error.localizedDescription)")
            audioEngine.inputNode.removeTap(onBus: 0)
            streamAnalyzer = nil
            currentRequest = nil
            resetDetectionState()
            clearAudioState()
            return false
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        if let silenceSourceNode {
            audioEngine.detach(silenceSourceNode)
            self.silenceSourceNode = nil
        }
        if let analyzer = streamAnalyzer, let request = currentRequest {
            try? analyzer.remove(request)
        }

        streamAnalyzer = nil
        currentRequest = nil
        recordingFormat = nil
        resetDetectionState()
        clearAudioState()
        listeningStartedAt = nil
        lastAudioBufferReceivedAt = nil
        lastAudioTapLogAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        print("AI stopped listening.")
    }
    
    private func systemClassificationRequest() throws -> SNClassifySoundRequest {
        if let systemRequest { return systemRequest }
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        request.overlapFactor = 0.5
        systemRequest = request
        return request
    }
    
    private func configureAudioSessionForContinuousListening() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setPreferredSampleRate(44_100)
        try audioSession.setPreferredIOBufferDuration(0.02)
        
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothHFP, .defaultToSpeaker, .mixWithOthers, .allowAirPlay]
        )
        
        try audioSession.setActive(true)
        
        if let builtInMic = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
            try? audioSession.setPreferredInput(builtInMic)
        }
    }
    
    private func installSilentOutputNode(sampleRate: Double) {
        if let silenceSourceNode {
            audioEngine.detach(silenceSourceNode)
            self.silenceSourceNode = nil
        }
        
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for buffer in buffers {
                guard let data = buffer.mData else { continue }
                memset(data, 0, Int(buffer.mDataByteSize))
            }
            return noErr
        }
        
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.mainMixerNode.outputVolume = 0.0001
        silenceSourceNode = sourceNode
    }
    
    private func logAudioTapIfNeeded(at date: Date) {
        guard lastAudioTapLogAt == nil || date.timeIntervalSince(lastAudioTapLogAt!) >= 5 else { return }
        lastAudioTapLogAt = date
    }
    
    private func logClassificationIfNeeded(label: String, confidence: Double, at date: Date) {
        guard lastClassificationLogAt == nil || date.timeIntervalSince(lastClassificationLogAt!) >= 5 else { return }
        lastClassificationLogAt = date
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let bestClassification = result.classifications.first else { return }
        
        let label = bestClassification.identifier
        let confidence = bestClassification.confidence
        logClassificationIfNeeded(label: label, confidence: confidence, at: Date())
        updatePendingRecording(with: label, confidence: confidence, at: Date())
        
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
        
        let detectedAt = Date()
        lastDetectionTimes[label] = detectedAt
        let detectionID = startDetectionRecording(label: label, confidence: confidence, detectedAt: detectedAt) ?? UUID()
        publishImmediateDetection(id: detectionID, label: label, confidence: confidence, detectedAt: detectedAt)
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("SoundAnalysis failed: \(error.localizedDescription)")
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
    
    private func startDetectionRecording(label: String, confidence: Double, detectedAt: Date) -> UUID? {
        guard let format = recordingFormat else { return nil }
        
        do {
            let detectionID = UUID()
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "Aura_Detection_\(sanitizedFileName(label))_\(Int(detectedAt.timeIntervalSince1970)).m4a"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: Int(format.channelCount),
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: settings)
            let targetFrameCount = AVAudioFramePosition(detectionRecordingDuration * format.sampleRate)
            var recording = PendingDetectionRecording(
                id: detectionID,
                label: label,
                confidence: confidence,
                detectedAt: detectedAt,
                fileURL: fileURL,
                audioFile: audioFile,
                targetFrameCount: targetFrameCount,
                writtenFrameCount: 0,
                lastActiveAt: detectedAt,
                quietingLogged: false,
                louderLogged: false,
                startLevel: nil,
                peakLevel: 0,
                timeline: [TimelineNode(exactTime: detectedAt, label: contextStartLabel(for: label))]
            )
            
            audioBufferLock.lock()
            for storedAudio in recentAudioBuffers {
                try audioFile.write(from: storedAudio.buffer)
                recording.writtenFrameCount += AVAudioFramePosition(storedAudio.buffer.frameLength)
            }
            pendingDetectionRecording = recording
            audioBufferLock.unlock()
            return detectionID
        } catch {
            print("Failed to start detection recording: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func updatePendingRecording(with label: String, confidence: Double, at date: Date) {
        audioBufferLock.lock()
        guard var recording = pendingDetectionRecording else {
            audioBufferLock.unlock()
            return
        }
        
        if label == recording.label && confidence >= activeSoundConfidence {
            recording.lastActiveAt = date
        } else if !recording.quietingLogged {
            recording.timeline.append(TimelineNode(exactTime: date, label: contextQuietingLabel(for: recording.label)))
            recording.quietingLogged = true
        }
        
        pendingDetectionRecording = recording
        audioBufferLock.unlock()
    }
    
    private func storeRecentAudio(_ buffer: AVAudioPCMBuffer, at startFramePosition: AVAudioFramePosition) {
        guard let copiedBuffer = copyAudioBuffer(buffer) else { return }
        let endFramePosition = startFramePosition + AVAudioFramePosition(buffer.frameLength)
        let maxStoredFrames = AVAudioFramePosition(detectionRecordingDuration * buffer.format.sampleRate)
        let audioLevel = rmsLevel(for: copiedBuffer)
        var completedDetection: SoundDetection?
        
        audioBufferLock.lock()
        recentAudioBuffers.append(BufferedAudio(buffer: copiedBuffer, endFramePosition: endFramePosition))
        recentAudioBuffers.removeAll { endFramePosition - $0.endFramePosition > maxStoredFrames }
        
        if var recording = pendingDetectionRecording {
            do {
                try recording.audioFile.write(from: copiedBuffer)
                recording.writtenFrameCount += AVAudioFramePosition(copiedBuffer.frameLength)
                
                if recording.startLevel == nil {
                    recording.startLevel = audioLevel
                }
                recording.peakLevel = max(recording.peakLevel, audioLevel)
                
                if !recording.louderLogged,
                   let startLevel = recording.startLevel,
                   audioLevel > startLevel * 1.8,
                   audioLevel > 0.02 {
                    recording.timeline.append(TimelineNode(exactTime: Date(), label: contextLouderLabel(for: recording.label)))
                    recording.louderLogged = true
                }
                
                if recording.writtenFrameCount >= recording.targetFrameCount {
                    var timeline = recording.timeline
                    if !recording.quietingLogged {
                        timeline.append(TimelineNode(exactTime: recording.lastActiveAt, label: contextQuietingLabel(for: recording.label)))
                    }
                    timeline.append(TimelineNode(exactTime: recording.lastActiveAt, label: "Silence"))
                    
                    completedDetection = SoundDetection(
                        id: recording.id,
                        name: recording.label,
                        confidence: recording.confidence,
                        timestamp: recording.detectedAt,
                        endedAt: recording.lastActiveAt,
                        timeline: timeline,
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
    
    private func publishImmediateDetection(id: UUID, label: String, confidence: Double, detectedAt: Date) {
        publish(
            SoundDetection(
                id: id,
                name: label,
                confidence: confidence,
                timestamp: detectedAt,
                endedAt: detectedAt,
                timeline: [TimelineNode(exactTime: detectedAt, label: contextStartLabel(for: label))],
                audioFileURL: nil
            )
        )
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
    
    private func rmsLevel(for buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        
        var sum: Float = 0
        for frame in 0..<frameLength {
            let sample = channelData[0][frame]
            sum += sample * sample
        }
        return sqrt(sum / Float(frameLength))
    }
    
    private func contextStartLabel(for label: String) -> String {
        let normalized = label.lowercased()
        if normalized.contains("alarm") || normalized.contains("siren") { return "an alarm or siren starting nearby" }
        if normalized.contains("horn") { return "a car horn sounding nearby" }
        if normalized.contains("glass") { return "a sharp glass-breaking sound" }
        if normalized.contains("door") || normalized.contains("knock") { return "a door or knocking sound" }
        if normalized.contains("baby") { return "a baby crying nearby" }
        return "\(formattedSoundName(label)) nearby"
    }
    
    private func contextQuietingLabel(for label: String) -> String {
        let normalized = label.lowercased()
        if normalized.contains("alarm") || normalized.contains("siren") { return "the alarm began to quiet down" }
        if normalized.contains("horn") { return "the horn faded out" }
        if normalized.contains("baby") { return "the crying softened" }
        return "the \(formattedSoundName(label).lowercased()) started to fade"
    }
    
    private func contextLouderLabel(for label: String) -> String {
        let normalized = label.lowercased()
        if normalized.contains("alarm") || normalized.contains("siren") { return "the alarm sounded like it was getting closer" }
        if normalized.contains("car") || normalized.contains("vehicle") { return "the vehicle sound seemed to get closer" }
        return "the \(formattedSoundName(label).lowercased()) got louder"
    }
    
    private func formattedSoundName(_ name: String) -> String {
        name
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
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
