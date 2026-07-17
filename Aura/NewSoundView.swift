//
//  NewSoundView.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

struct NewSoundView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var soundManager: SoundManager
    @StateObject private var audioRecorder = AudioRecorder()
    
    @State private var showNamingScreen = false
    @State private var currentStep: Int = 1
    
    @State private var isRecording: Bool = false
    @State private var isReviewingSample: Bool = false
    @State private var timeElapsed: Int = 0
    @State private var timer: Timer? = nil
    
    @State private var soundName: String = ""
    @State private var soundNote: String = ""
    
    var body: some View {
        VStack {
            if showNamingScreen {
                namingScreen
                    .transition(.move(edge: .trailing))
            } else {
                recordingScreen
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showNamingScreen)
        .onDisappear {
            stopTimer()
            if isRecording { audioRecorder.stopRecording() }
            audioRecorder.stopPlayback()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var recordingScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(spacing: 16) {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Text("Aura")
                    .font(.custom("MarkerFelt-Thin", size: 30))
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("New sound")
                    .font(.system(size: 20, weight: .bold))
                
                Text("\(sampleStatusText): Record from different angles and distances for best accuracy")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
            HStack(spacing: 8) {
                ForEach(1...3, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? Color(white: 0.4) : Color(white: 0.9))
                        .frame(height: 6)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(isRecording ? Color.red : Color.gray,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: isRecording ? [] : [8, 10]))
                        .frame(width: 160, height: 160)
                        .scaleEffect(isRecording ? 1.05 : 1.0)
                        .animation(isRecording ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isRecording)
                    
                    Image(systemName: centerIconName)
                        .font(.system(size: 54))
                        .foregroundColor(isRecording ? .red : (isReviewingSample ? .green : .black))
                }
                .onTapGesture {
                    if isReviewingSample {
                        if audioRecorder.isPlaying {
                            audioRecorder.stopPlayback()
                        } else {
                            audioRecorder.startPlayback(fileName: "Aura_Sample_\(currentStep)")
                        }
                    }
                }
                
                if isRecording {
                    Text(String(format: "0:%02d / 0:10", timeElapsed))
                        .font(.system(size: 24, weight: .bold).monospacedDigit())
                        .foregroundColor(.red)
                } else {
                    Text(centerStatusText)
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            
            Spacer()
            
            Divider()
                .background(Color.black)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            if isReviewingSample {
                HStack(spacing: 16) {
                    Button(action: {
                        audioRecorder.stopPlayback()
                        withAnimation { isReviewingSample = false }
                    }) {
                        Text("Record again")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                    
                    Button(action: advanceToNextStep) {
                        Text(currentStep == 3 ? "Name the sound" : "Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            } else {
                Button(action: handleMainAction) {
                    Text(buttonLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isRecording ? .red : .black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isRecording ? Color.red.opacity(0.5) : Color.gray.opacity(0.4), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var namingScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Save Sound")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sound Name")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    TextField("e.g. Front Door Shut", text: $soundName)
                        .padding()
                        .background(Color(white: 0.95))
                        .cornerRadius(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes (Optional)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    TextField("e.g. Recorded in the hallway, slight echo", text: $soundNote, axis: .vertical)
                        .lineLimit(4...8)
                        .padding()
                        .background(Color(white: 0.95))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            Button(action: {
                print("Saving sound: \(soundName) with note: \(soundNote)")
                soundManager.addSound(name: soundName, notes: soundNote)
                dismiss()
            }) {
                Text("Save to Library")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(soundName.isEmpty ? Color.gray : Color.black)
                    .cornerRadius(12)
            }
            .disabled(soundName.isEmpty)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    private func goBack() {
        audioRecorder.stopPlayback()
        withAnimation(.easeInOut) {
            if showNamingScreen {
                showNamingScreen = false
            } else if isReviewingSample {
                isReviewingSample = false
            } else if currentStep > 1 {
                stopTimer()
                if isRecording { audioRecorder.stopRecording() }
                isRecording = false
                currentStep -= 1
            } else {
                dismiss()
            }
        }
    }
    
    private func handleMainAction() {
        withAnimation(.easeInOut) {
            if isRecording {
                finishCurrentSample()
            } else {
                startRecording()
            }
        }
    }
    
    private func startRecording() {
        isRecording = true
        isReviewingSample = false
        timeElapsed = 0
        
        audioRecorder.startRecording(fileName: "Aura_Sample_\(currentStep)")
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            timeElapsed += 1
            if timeElapsed >= 10 {
                withAnimation(.easeInOut) { finishCurrentSample() }
            }
        }
    }
    
    private func finishCurrentSample() {
        stopTimer()
        audioRecorder.stopRecording()
        isRecording = false
        isReviewingSample = true
    }
    
    private func advanceToNextStep() {
        audioRecorder.stopPlayback()
        withAnimation(.easeInOut) {
            isReviewingSample = false
            if currentStep < 3 {
                currentStep += 1
            } else {
                showNamingScreen = true
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private var sampleStatusText: String {
        return currentStep <= 3 ? "Sample \(currentStep) of 3" : "Sample 3 of 3"
    }
    
    private var centerStatusText: String {
        if isReviewingSample {
            return audioRecorder.isPlaying ? "Playing..." : "Tap to listen"
        }
        return currentStep <= 3 ? "Record sample \(currentStep)" : "Sound Recorded"
    }
    
    private var centerIconName: String {
        if isRecording { return "waveform" }
        if isReviewingSample {
            return audioRecorder.isPlaying ? "stop.fill" : "play.fill"
        }
        return "mic"
    }
    
    private var buttonLabel: String {
        return isRecording ? "Stop recording" : "Start recording"
    }
}

#Preview {
    NewSoundView()
}
