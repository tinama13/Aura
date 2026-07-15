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

class SoundRecognizer: NSObject, ObservableObject, SNResultsObserving {
    private let audioEngine = AVAudioEngine()
    private var streamAnalyzer: SNAudioStreamAnalyzer?
    
    @Published var detectedSound: String = "Waiting for sound..."
    @Published var confidence: Double = 0.0
    
    func startListening() {
        guard let model = try? AuraSoundDetection(configuration: MLModelConfiguration()) else {
            print("Failed to load the Create ML model.")
            return
        }
        
        let mlModel = model.model
        
        do {
            let request = try SNClassifySoundRequest(mlModel: mlModel)
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true)
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            streamAnalyzer = SNAudioStreamAnalyzer(format: recordingFormat)
            try streamAnalyzer?.add(request, withObserver: self)
            
            inputNode.installTap(onBus: 0, bufferSize: 8192, format: recordingFormat) { buffer, time in
                self.streamAnalyzer?.analyze(buffer, atAudioFramePosition: time.sampleTime)
            }
            
            try audioEngine.start()
            print("AI is now actively listening!")
            
        } catch {
            print("Error starting AI: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        print("AI stopped listening.")
    }
    
    func request(_ request: SNRequest, didProduce result: SNResult) {
        guard let result = result as? SNClassificationResult,
              let bestClassification = result.classifications.first else { return }
        
        if bestClassification.confidence > 0.75 {
            DispatchQueue.main.async {
                self.detectedSound = bestClassification.identifier
                self.confidence = bestClassification.confidence
                print("AI Heard: \(bestClassification.identifier)")
            }
        }
    }
    
    func request(_ request: SNRequest, didFailWithError error: Error) {
        print("AI Analysis failed: \(error.localizedDescription)")
    }
}
