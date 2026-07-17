//
//  SoundsView.swift
//  Aura
//
//  Created by Tina Ma on 7/14/26.
//

import SwiftUI

struct SoundsView: View {
    @EnvironmentObject var soundManager: SoundManager

    var groupedSounds: [(String, [Sound])] {
        let sorted = soundManager.sounds.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        let grouped = Dictionary(grouping: sorted) { sound in
            String(sound.name.prefix(1)).uppercased()
        }

        return grouped.sorted { $0.key < $1.key }
    }

    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        // No NavigationStack here — ContentView provides one for the whole app,
        // so the NavigationLinks below push their screens over the full screen.
        VStack(spacing: 0) {
            HStack {
                Text("Aura")
                    .font(.custom("MarkerFelt-Thin", size: 30))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            HStack {
                Text("All Sounds")
                    .font(.system(size: 25, weight: .bold))
                Spacer()

                NavigationLink(destination: NewSoundView()) {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(red: 0.204, green: 0.678, blue: 0.914))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color(white: 0.93)))
                        .overlay(Circle().stroke(.black, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            ScrollViewReader { proxy in

                HStack(spacing: 0) {

                    ScrollView {
                        VStack(spacing: 24) {
                            ForEach(groupedSounds, id: \.0) { letter, soundsInGroup in
                                VStack(spacing: 12) {
                                    HStack {
                                        Text(letter)
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.gray)
                                        Spacer()
                                    }
                                    .id(letter)

                                    ForEach(soundsInGroup) { sound in
                                        NavigationLink(destination: SoundDetailView(soundName: sound.name)) {
                                            HStack {
                                                Text(sound.name)
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.black)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                            .background(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(.black, lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }

                    VStack(spacing: 2) {
                        ForEach(alphabet, id: \.self) { char in
                            let letter = String(char)
                            Text(letter)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                                .frame(width: 24, height: 16)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if groupedSounds.contains(where: { $0.0 == letter }) {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            proxy.scrollTo(letter, anchor: .top)
                                        }
                                    }
                                }
                        }
                    }
                    .padding(.trailing, 6)

                }
                .padding(.horizontal)
            }

        }
    }
}

#Preview {
    // The preview needs its own NavigationStack (the app gets one from
    // ContentView, but this preview shows SoundsView alone).
    NavigationStack {
        SoundsView()
    }
    .environmentObject(SoundManager())
    .environmentObject(PresetManager())
    .environmentObject(HistoryManager())
}
