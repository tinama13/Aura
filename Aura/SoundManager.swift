//
//  SoundManager.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import Foundation
import SwiftUI
import Combine

struct Sound: Identifiable, Codable {
    var id = UUID()
    var name: String
    var isUserCreated: Bool = false
    var notes: String = ""
}

class SoundManager: ObservableObject {
    private static let savedSoundsKey = "savedSounds"
    
    private static let defaultSounds: [Sound] = [
        Sound(name: "Sirens and alarms"),
        Sound(name: "Car horns"),
        Sound(name: "Emergency vehicles"),
        Sound(name: "Train"),
        Sound(name: "Motorcycles"),
        Sound(name: "Tires screeching"),
        Sound(name: "Crosswalk signals"),
        Sound(name: "Bike bells"),
        Sound(name: "Approaching cars"),
        Sound(name: "People shouting"),
        Sound(name: "Scooters"),
        Sound(name: "Dogs barking"),
        Sound(name: "Doorbell"),
        Sound(name: "Kitchen timer"),
        Sound(name: "Smoke alarm"),
        Sound(name: "Baby crying"),
        Sound(name: "Glass breaking"),
        Sound(name: "Knocking"),
        Sound(name: "Appliance beeps"),
        Sound(name: "Name called"),
        Sound(name: "Annoucements"),
        Sound(name: "Phone ringing"),
        Sound(name: "Loud alarms"),
        Sound(name: "Crowd alerts"),
        Sound(name: "Security beeps")
    ]
    
    @Published var sounds: [Sound] = defaultSounds {
        didSet {
            saveSounds()
        }
    }
    
    init() {
        loadSounds()
    }
    
    func addSound(name: String, notes: String = "") {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let index = sounds.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }) {
            sounds[index].notes = notes
            return
        }
        
        let newSound = Sound(name: trimmedName, isUserCreated: true, notes: notes)
        sounds.append(newSound)
    }
    
    func deleteSound(name: String) {
        sounds.removeAll { $0.name == name }
    }

    func renameSound(from oldName: String, to newName: String) -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        guard let index = sounds.firstIndex(where: { $0.name == oldName && $0.isUserCreated }) else { return false }

        let nameAlreadyExists = sounds.contains {
            $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame && $0.name != oldName
        }
        guard !nameAlreadyExists else { return false }

        sounds[index].name = trimmedName
        return true
    }

    func updateNotes(for name: String, notes: String) {
        if let index = sounds.firstIndex(where: { $0.name == name }) {
            sounds[index].notes = notes
        }
    }
    
    private func loadSounds() {
        guard let data = UserDefaults.standard.data(forKey: Self.savedSoundsKey),
              let savedSounds = try? JSONDecoder().decode([Sound].self, from: data) else {
            sounds = Self.defaultSounds
            return
        }
        
        let savedByName = savedSounds.reduce(into: [String: Sound]()) { soundsByName, sound in
            soundsByName[sound.name] = sound
        }
        let defaultsWithSavedNotes = Self.defaultSounds.map { defaultSound in
            guard let savedSound = savedByName[defaultSound.name] else { return defaultSound }
            return Sound(id: defaultSound.id, name: defaultSound.name, isUserCreated: false, notes: savedSound.notes)
        }
        let customSounds = savedSounds.filter { $0.isUserCreated }
        sounds = defaultsWithSavedNotes + customSounds
    }
    
    private func saveSounds() {
        guard let data = try? JSONEncoder().encode(sounds) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedSoundsKey)
    }
}
