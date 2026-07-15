//
//  NewPresetView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct NewPresetView: View {
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var soundManager: SoundManager
    @Environment(\.dismiss) var dismiss
    
    @State private var presetName = ""
    @State private var selectedSounds = Set<String>()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                
                Spacer()
                
                Text("New Preset")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Preset Name")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        TextField("e.g. Focus Mode", text: $presetName)
                            .padding()
                            .background(Color(white: 0.95))
                            .cornerRadius(12)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Sounds")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 12) {
                            ForEach(soundManager.sounds) { sound in
                                HStack {
                                    Text(sound.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    if selectedSounds.contains(sound.name) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                                            .font(.system(size: 22))
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray.opacity(0.3))
                                            .font(.system(size: 22))
                                    }
                                }
                                .padding()
                                .background(Color(white: 0.98))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedSounds.contains(sound.name) {
                                        selectedSounds.remove(sound.name)
                                    } else {
                                        selectedSounds.insert(sound.name)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            
            VStack {
                Button(action: {
                    presetManager.createNewPreset(
                        title: presetName,
                        icon: "star.fill",
                        sounds: selectedSounds
                    )
                    dismiss()
                }) {
                    Text("Save Preset")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(presetName.isEmpty ? Color.gray : Color.black)
                        .cornerRadius(12)
                }
                .disabled(presetName.isEmpty)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .padding(.top, 10)
            }
        }
        .navigationBarBackButtonHidden(true)
        .background(Color.white)
    }
}

#Preview {
    NewPresetView()
        .environmentObject(PresetManager())
        .environmentObject(SoundManager())
}
