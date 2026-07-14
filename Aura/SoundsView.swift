//
//  SoundsView.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

// One sound the app can listen for. Identifiable lets ForEach tell rows apart.
struct Sound: Identifiable {
    let id = UUID()
    let name: String
    var isSelected = false
}

struct SoundsView: View {
    // The sounds shown in the list. Later this can come from SoundAnalysis
    // or the user's own trained sounds instead of being hardcoded.
    @State private var sounds = [
        Sound(name: "Sirens and alarms", isSelected: true),
        Sound(name: "Car horns"),
        Sound(name: "Dog barking"),
        Sound(name: "Microwave Beeping"),
        Sound(name: "Knocking"),
        Sound(name: "Kettle"),
        Sound(name: "Baby crying"),
        Sound(name: "Doorbell"),
    ]

    var body: some View {
        // NavigationStack is what makes NavigationLink work — a link can only
        // navigate when there's a stack for it to push the new screen onto.
        NavigationStack {
            VStack {
                HStack {
                    Text("Aura")
                        .font(.custom("Noteworthy", size: 20))
                        .fontWeight(.bold)
                    Spacer()
                }
                .padding()

                HStack {
                    Text("All Sounds").font(.system(size: 25, weight: .bold))
                    Spacer()

                    NavigationLink(destination: NewSoundView()) {
                        Image(systemName: "plus").font(.system(size: 25, weight: .bold))
                            .foregroundStyle(Color(red: 0.204, green: 0.678, blue: 0.914))          // plus sign color
                            .frame(width: 44, height: 44)     // fixed circle size — plus size won't change it
                            .background(Circle().fill(Color(white: 0.85)))   // circle color
                            .overlay(
                                Circle().stroke(.black, lineWidth: 1)  // tiny line around the circle
                            )
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                .padding(.leading)

                // The list of sound rows. ForEach makes one row per item in `sounds`.
                // The $ gives each row a *writable* connection, so tapping can
                // flip that sound's isSelected back in the array.
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($sounds) { $sound in
                            Button {
                                sound.isSelected.toggle()
                            } label: {
                                HStack {
                                    Text(sound.name)
                                    Spacer()
                                    if sound.isSelected {
                                        Image(systemName: "checkmark")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .padding()
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(.black, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview {
    SoundsView()
}
