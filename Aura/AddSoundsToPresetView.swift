//
//  AddSoundsToPresetView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct AddSoundsToPresetView: View {
    @EnvironmentObject var presetManager: PresetManager
    @EnvironmentObject var soundManager: SoundManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AuraHeaderView()
                
                List(soundManager.sounds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) { sound in
                    HStack {
                        Text(sound.name)
                            .font(.system(size: 17, weight: .semibold))
                        
                        Spacer()
                        
                        if presetManager.isSoundSelected(presetID: presetManager.activePresetID, soundName: sound.name) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                                .font(.system(size: 22))
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.gray.opacity(0.5))
                                .font(.system(size: 22))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        presetManager.toggleSelection(presetID: presetManager.activePresetID, soundName: sound.name)
                    }
                }
            }
            .navigationTitle("Add to \(presetManager.activePreset.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                }
            }
        }
    }
}

#Preview {
    AddSoundsToPresetView()
        .environmentObject(PresetManager())
        .environmentObject(SoundManager())
}
