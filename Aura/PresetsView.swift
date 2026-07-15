//
//  PresetsView.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI
import Combine

struct PresetsView: View {
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var soundManager: SoundManager
    
    @State private var showingNewPresetSheet = false
    @State private var showingAddSheet = false
    @State private var showingAllPresetsSheet = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Aura")
                    .font(.custom("MarkerFelt-Thin", size: 34))
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding(.top, 34)
            .padding(.horizontal, 26)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presetManager.favoritePresets) { preset in
                    PresetModeButton(
                        preset: preset,
                        isSelected: presetManager.activePresetID == preset.id
                    ) {
                        presetManager.activePresetID = preset.id
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 26)
            
            Button(action: {
                showingAllPresetsSheet = true
            }) {
                HStack {
                    Text("View all presets")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.system(size: 16, weight: .semibold))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(white: 0.95))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .sheet(isPresented: $showingAllPresetsSheet) {
                AllPresetsView()
            }
            
            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(height: 2)
                .padding(.top, 20)
                .padding(.horizontal, 26)
            
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center) {
                    Text("Preset for \(presetManager.activePreset.title)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.black)
                    
                    Spacer()
                    
                    Button("Select all") {
                        presetManager.addAllToPreset(presetID: presetManager.activePresetID, allSounds: soundManager.sounds)
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 0.204, green: 0.678, blue: 0.914))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.204, green: 0.678, blue: 0.914).opacity(0.1))
                    .clipShape(Capsule())
                }
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(presetManager.getVisibleSounds(for: presetManager.activePreset), id: \.self) { category in
                            CategoryRow(
                                title: category,
                                isSelected: presetManager.isSoundSelected(presetID: presetManager.activePresetID, soundName: category)
                            ) {
                                presetManager.toggleSelection(presetID: presetManager.activePresetID, soundName: category)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
                }
                .frame(maxHeight: .infinity)
                
                Button("Add More Sounds") {
                    showingAddSheet = true
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.blue)
                .padding(.top, 10)
                .sheet(isPresented: $showingAddSheet) {
                    AddSoundsToPresetView()
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 26)
            
            Spacer()
            
            Button {
                showingNewPresetSheet = true // 👉 FIXED: This triggers the sheet to open
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Make New Preset")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(width: 196, height: 45)
                .background(Color(red: 0.42, green: 0.29, blue: 0.72))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 40)
            .sheet(isPresented: $showingNewPresetSheet) { // 👉 FIXED: This tells it which view to show
                NewPresetView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}

// MARK: - Subviews

private struct PresetModeButton: View {
    let preset: Preset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.black.opacity(0.9))
                    .frame(width: 62, height: 54)
                
                Text(preset.title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .background(isSelected ? Color(red: 0.85, green: 0.95, blue: 1.0) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.36, green: 0.72, blue: 0.86) : Color.black.opacity(0.38), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CategoryRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 36)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.38), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PresetsView()
        .environmentObject(SoundManager())
        .environmentObject(PresetManager())
        .environmentObject(HistoryManager())
}
