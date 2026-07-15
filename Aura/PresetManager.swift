//
//  PresetManager.swift
//  Aura
//

import SwiftUI
import Combine

struct Preset: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var iconName: String
    var defaultSounds: [String]
    var isFavorite: Bool = false
}

class PresetManager: ObservableObject {
    @Published var presets: [Preset] = [
        Preset(title: "Driving", iconName: "steeringwheel", defaultSounds: ["Sirens and alarms", "Car horns", "Emergency vehicles", "Train crossings", "Motorcycles", "Tires screeching"], isFavorite: true),
        Preset(title: "Walking", iconName: "figure.walk", defaultSounds: ["Crosswalk signals", "Bike bells", "Approaching cars", "People shouting", "Scooters", "Dogs barking"], isFavorite: true),
        Preset(title: "Home", iconName: "house.fill", defaultSounds: ["Doorbell", "Kitchen timer", "Smoke alarm", "Baby crying", "Glass breaking", "Appliance beeps"], isFavorite: true),
        Preset(title: "Public", iconName: "speaker.wave.2.fill", defaultSounds: ["Name called", "Announcements", "Phone ringing", "Loud alarms", "Crowd alerts", "Security beeps"], isFavorite: true)
    ]
    
    @Published var activePresetID: UUID = UUID()
    @Published var selectedSounds: [UUID: Set<String>] = [:]
    
    init() {
        self.activePresetID = presets.first?.id ?? UUID()
    }
    
    var activePreset: Preset {
        presets.first(where: { $0.id == activePresetID }) ?? presets[0]
    }
    
    var favoritePresets: [Preset] {
        return Array(presets.filter { $0.isFavorite }.prefix(4))
    }
    
    func toggleFavorite(presetID: UUID) -> Bool {
        guard let index = presets.firstIndex(where: { $0.id == presetID }) else { return true }
        
        if presets[index].isFavorite {
            presets[index].isFavorite = false
            return true
        } else {
            if presets.filter({ $0.isFavorite }).count < 4 {
                presets[index].isFavorite = true
                return true
            } else {
                return false
            }
        }
    }
    
    func getVisibleSounds(for preset: Preset) -> [String] {
        let defaults = Set(preset.defaultSounds)
        let currentlySelected = selectedSounds[preset.id] ?? Set(preset.defaultSounds)
        let combined = defaults.union(currentlySelected)
        return Array(combined).sorted()
    }
    
    func isSoundSelected(presetID: UUID, soundName: String) -> Bool {
        if let savedChoices = selectedSounds[presetID] {
            return savedChoices.contains(soundName)
        }
        let preset = presets.first(where: { $0.id == presetID })!
        return preset.defaultSounds.contains(soundName)
    }
    
    func toggleSelection(presetID: UUID, soundName: String) {
        let preset = presets.first(where: { $0.id == presetID })!
        var current = selectedSounds[presetID] ?? Set(preset.defaultSounds)
        
        if current.contains(soundName) {
            current.remove(soundName)
        } else {
            current.insert(soundName)
        }
        selectedSounds[presetID] = current
    }
    
    func addAllToPreset(presetID: UUID, allSounds: [Sound]) {
        let allSoundNames = Set(allSounds.map { $0.name })
        selectedSounds[presetID] = allSoundNames
    }
    
    func createNewPreset(title: String, icon: String, sounds: Set<String>) {
        let newPreset = Preset(title: title, iconName: icon, defaultSounds: Array(sounds))
        presets.append(newPreset)
    }
}
