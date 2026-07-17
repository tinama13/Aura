//
//  PresetManager.swift
//  Aura
//

import SwiftUI
import Combine

struct Preset: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var iconName: String
    var defaultSounds: [String]
    var isFavorite: Bool = false
}

class PresetManager: ObservableObject {
    private static let savedPresetsKey = "savedPresets"
    private static let savedActivePresetIDKey = "savedActivePresetID"
    private static let savedSelectedSoundsKey = "savedSelectedSounds"
    
    private static let defaultPresets: [Preset] = [
        Preset(title: "Driving", iconName: "steeringwheel", defaultSounds: ["Sirens and alarms", "Car horns", "Emergency vehicles", "Train crossings", "Motorcycles", "Tires screeching"], isFavorite: true),
        Preset(title: "Walking", iconName: "figure.walk", defaultSounds: ["Crosswalk signals", "Bike bells", "Approaching cars", "People shouting", "Scooters", "Dogs barking"], isFavorite: true),
        Preset(title: "Home", iconName: "house.fill", defaultSounds: ["Doorbell", "Kitchen timer", "Smoke alarm", "Baby crying", "Glass breaking", "Appliance beeps"], isFavorite: true),
        Preset(title: "Public", iconName: "speaker.wave.2.fill", defaultSounds: ["Name called", "Announcements", "Phone ringing", "Loud alarms", "Crowd alerts", "Security beeps"], isFavorite: true)
    ]
    
    @Published var presets: [Preset] = defaultPresets {
        didSet {
            savePresets()
        }
    }
    
    @Published var activePresetID: UUID = UUID() {
        didSet {
            saveActivePresetID()
        }
    }
    
    @Published var selectedSounds: [UUID: Set<String>] = [:] {
        didSet {
            saveSelectedSounds()
        }
    }
    
    init() {
        loadSavedState()
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
    
    func orderedSounds(for preset: Preset, allSounds: [Sound]) -> [String] {
        let defaultSounds = Set(preset.defaultSounds)
        let selected = (selectedSounds[preset.id] ?? Set(preset.defaultSounds)).union(defaultSounds)
        let allSoundNames = Set(allSounds.map { $0.name })
        let visibleSoundNames = allSoundNames.union(selected).union(defaultSounds)
        
        let defaultRows = preset.defaultSounds.filter { visibleSoundNames.contains($0) }
        let selectedRows = selected
            .subtracting(defaultSounds)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let uncheckedRows = visibleSoundNames
            .subtracting(selected)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        
        return defaultRows + selectedRows + uncheckedRows
    }
    
    func isSoundSelected(presetID: UUID, soundName: String) -> Bool {
        if isDefaultSound(presetID: presetID, soundName: soundName) {
            return true
        }
        
        if let savedChoices = selectedSounds[presetID] {
            return savedChoices.contains(soundName)
        }
        let preset = presets.first(where: { $0.id == presetID })!
        return preset.defaultSounds.contains(soundName)
    }
    
    func toggleSelection(presetID: UUID, soundName: String) {
        let preset = presets.first(where: { $0.id == presetID })!
        guard !preset.defaultSounds.contains(soundName) else { return }
        
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
    
    func removeAllFromPreset(presetID: UUID) {
        let defaults = presets.first(where: { $0.id == presetID })?.defaultSounds ?? []
        selectedSounds[presetID] = Set(defaults)
    }
    
    func areAllSoundsSelected(presetID: UUID, allSounds: [Sound]) -> Bool {
        let allSoundNames = Set(allSounds.map { $0.name })
        guard !allSoundNames.isEmpty else { return false }
        let selected = selectedSounds[presetID] ?? Set(presets.first(where: { $0.id == presetID })?.defaultSounds ?? [])
        return allSoundNames.isSubset(of: selected)
    }
    
    func isDefaultSound(presetID: UUID, soundName: String) -> Bool {
        presets.first(where: { $0.id == presetID })?.defaultSounds.contains(soundName) ?? false
    }
    
    func createNewPreset(title: String, icon: String, sounds: Set<String>) {
        let sortedSounds = sounds.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        let newPreset = Preset(title: title, iconName: icon, defaultSounds: sortedSounds, isFavorite: true)
        presets.insert(newPreset, at: 0)
        activePresetID = newPreset.id
        keepFirstFourFavorites()
    }
    
    private func keepFirstFourFavorites() {
        let favoriteIndices = presets.indices.filter { presets[$0].isFavorite }
        for index in favoriteIndices.dropFirst(4) {
            presets[index].isFavorite = false
        }
    }
    
    private func loadSavedState() {
        if let data = UserDefaults.standard.data(forKey: Self.savedPresetsKey),
           let savedPresets = try? JSONDecoder().decode([Preset].self, from: data),
           !savedPresets.isEmpty {
            presets = savedPresets
        } else {
            presets = Self.defaultPresets
        }
        
        if let data = UserDefaults.standard.data(forKey: Self.savedSelectedSoundsKey),
           let savedSelectedSounds = try? JSONDecoder().decode([UUID: Set<String>].self, from: data) {
            selectedSounds = savedSelectedSounds.filter { presetID, _ in
                presets.contains { $0.id == presetID }
            }
        }
        
        if let savedIDString = UserDefaults.standard.string(forKey: Self.savedActivePresetIDKey),
           let savedID = UUID(uuidString: savedIDString),
           presets.contains(where: { $0.id == savedID }) {
            activePresetID = savedID
        } else {
            activePresetID = presets.first?.id ?? UUID()
        }
    }
    
    private func savePresets() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedPresetsKey)
    }
    
    private func saveActivePresetID() {
        UserDefaults.standard.set(activePresetID.uuidString, forKey: Self.savedActivePresetIDKey)
    }
    
    private func saveSelectedSounds() {
        guard let data = try? JSONEncoder().encode(selectedSounds) else { return }
        UserDefaults.standard.set(data, forKey: Self.savedSelectedSoundsKey)
    }
}
