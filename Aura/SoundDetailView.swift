//
//  SoundDetailView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct SoundDetailView: View {
    let soundName: String
    @State private var editedName: String = ""
    @State private var notes: String = ""
    @State private var validationMessage: String?
    @Environment(\.dismiss) private var dismiss
    
    @EnvironmentObject var soundManager: SoundManager
    @EnvironmentObject var presetManager: PresetManager
    
    private func saveNote() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            validationMessage = "Name cannot be empty."
            return
        }

        var savedSoundName = soundName
        if isCustomSound && trimmedName != soundName {
            guard soundManager.renameSound(from: soundName, to: trimmedName) else {
                validationMessage = "A sound with that name already exists."
                return
            }
            presetManager.renameSound(from: soundName, to: trimmedName)
            savedSoundName = trimmedName
        }

        soundManager.updateNotes(for: savedSoundName, notes: notes)
        dismiss()
    }
    
    var isCustomSound: Bool {
        if let sound = soundManager.sounds.first(where: { $0.name == soundName }) {
            return sound.isUserCreated
        }
        return false
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            AuraHeaderView()
            
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                Spacer()
                Text(editedName.isEmpty ? soundName : editedName)
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
                    
                    if isCustomSound {
                        TextField("Sound name", text: $editedName)
                            .padding()
                            .background(Color(white: 0.95))
                            .cornerRadius(12)
                            .onChange(of: editedName) {
                                validationMessage = nil
                            }

                        if let validationMessage {
                            Text(validationMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.red)
                        }
                    } else {
                        Text(soundName)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(white: 0.95))
                            .cornerRadius(12)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                    
                    TextField("Add notes about this sound...", text: $notes, axis: .vertical)
                        .lineLimit(4...8)
                        .padding()
                        .background(Color(white: 0.95))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
//            Button("Save Note") {
//                /*@START_MENU_TOKEN@*//*@PLACEHOLDER=Action@*/ /*@END_MENU_TOKEN@*/
//            }
            Group{
                if isCustomSound {
                    HStack(spacing: 12) {
                        Button(action: saveNote){
                            Text("Save Note").font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.204, green: 0.678, blue: 0.914))
                                .cornerRadius(12)
                        }
                        Button(action: {
                                        soundManager.deleteSound(name: soundName)
                                        dismiss()
                                    }) {
                                        Text("Delete Sound")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Color.red)
                                            .cornerRadius(12)
                                    }
                                }
                        
                    }
                else {
                        Button(action: saveNote) {
                            Text("Save Note")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.204, green: 0.678, blue: 0.914))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
//            if isCustomSound {
//                Button(action: {
//                    soundManager.deleteSound(name: soundName)
//                    dismiss()
//                }) {
//                    Text("Delete Sound")
//                        .font(.system(size: 16, weight: .bold))
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding(.vertical, 16)
//                        .background(Color.red)
//                        .cornerRadius(12)
//                }
//                .padding(.horizontal, 24)
//                .padding(.bottom, 20)
//            }
//        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Show any note that was saved for this sound before
            editedName = soundName
            notes = soundManager.sounds.first(where: { $0.name == soundName })?.notes ?? ""
        }
    }
}

#Preview {
    SoundDetailView(soundName: "Microwave Beeping")
        .environmentObject(SoundManager())
}
