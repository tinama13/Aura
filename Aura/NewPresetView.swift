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
    @State private var selectedIcon = "star.fill"
    
    private let presetIcons = [
        "star.fill",
        "house.fill",
        "car.fill",
        "figure.walk",
        "speaker.wave.2.fill",
        "bell.fill",
        "moon.fill",
        "sun.max.fill",
        "briefcase.fill",
        "book.fill",
        "heart.fill",
        "person.fill"
    ]
    
    private var sortedSounds: [Sound] {
        soundManager.sounds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private var areAllSoundsSelected: Bool {
        let soundNames = Set(sortedSounds.map { $0.name })
        return !soundNames.isEmpty && soundNames.isSubset(of: selectedSounds)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AuraHeaderView()
            
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
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preset Symbol")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(presetIcons, id: \.self) { iconName in
                                Button {
                                    selectedIcon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(selectedIcon == iconName ? .white : .black)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 48)
                                        .background(selectedIcon == iconName ? Color(red: 0.204, green: 0.678, blue: 0.914) : Color(white: 0.95))
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Select Sounds")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button {
                                if areAllSoundsSelected {
                                    selectedSounds.removeAll()
                                } else {
                                    selectedSounds = Set(sortedSounds.map { $0.name })
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: areAllSoundsSelected ? "minus.circle.fill" : "checkmark.circle.fill")
                                        .font(.system(size: 15, weight: .bold))
                                    Text(areAllSoundsSelected ? "Deselect All Sounds" : "Select All Sounds")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundColor(areAllSoundsSelected ? Color(red: 0.42, green: 0.29, blue: 0.72) : .white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(areAllSoundsSelected ? Color(red: 0.94, green: 0.91, blue: 0.98) : Color(red: 0.204, green: 0.678, blue: 0.914))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(sortedSounds.isEmpty)
                            .opacity(sortedSounds.isEmpty ? 0.45 : 1)
                        }
                        
                        VStack(spacing: 12) {
                            ForEach(sortedSounds) { sound in
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
                        icon: selectedIcon,
                        sounds: selectedSounds
                    )
                    dismiss()
                }) {
                    Text("Save Preset")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(presetName.isEmpty ? Color.gray : Color(red: 0.42, green: 0.29, blue: 0.72))
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
