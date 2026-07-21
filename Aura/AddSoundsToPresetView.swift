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
    @AppStorage("auraTutorialStepName") private var tutorialStepName = ""
    
    private var isShowingDoneTutorial: Bool {
        tutorialStepName == "addPresetDone"
    }
    
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
                        guard tutorialStepName.isEmpty else { return }
                        presetManager.toggleSelection(presetID: presetManager.activePresetID, soundName: sound.name)
                    }
                }
            }
            .navigationTitle("Add to \(presetManager.activePreset.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isShowingDoneTutorial {
                            NotificationCenter.default.post(name: .auraTutorialAddSoundsDone, object: nil)
                        }
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .overlay {
                                if isShowingDoneTutorial {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(
                                            Color(red: 0.58, green: 0.86, blue: 1.0),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [7, 5])
                                        )
                                }
                            }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isShowingDoneTutorial)
    }
}

#Preview {
    AddSoundsToPresetView()
        .environmentObject(PresetManager())
        .environmentObject(SoundManager())
}
