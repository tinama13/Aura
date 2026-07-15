//
//  SoundManager.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import Foundation
import SwiftUI
import Combine

struct Sound: Identifiable {
    let id = UUID()
    let name: String
    var isUserCreated: Bool = false
}

class SoundManager: ObservableObject {
    @Published var sounds: [Sound] = [
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
    
    func addSound(name: String) {
        let newSound = Sound(name: name, isUserCreated: true)
        sounds.append(newSound)
    }
    
    func deleteSound(name: String) {
        sounds.removeAll { $0.name == name }
    }
}
