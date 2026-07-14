//
//  PresetsView.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

struct PresetsView: View {
    @State private var selectedPreset: PresetMode = .driving
    @State private var selectedCategories: [PresetMode: Set<String>] = [
        .driving: ["Sirens and alarms"],
        .walking: ["Crosswalk signals"],
        .home: ["Doorbell"],
        .publicPlace: ["Name called"]
    ]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Aura")
                    .font(.custom("Snell Roundhand", size: 34))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)

                Spacer()

                Button("View all") {
                    selectAllCategories()
                }
                .font(.custom("Itim", size: 23))
                .fontWeight(.bold)
                .foregroundStyle(.black)
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.75), lineWidth: 1)
                }
            }
            .padding(.top, 34)
            .padding(.horizontal, 26)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PresetMode.allCases) { preset in
                    PresetModeButton(
                        preset: preset,
                        isSelected: selectedPreset == preset
                    ) {
                        selectedPreset = preset
                    }
                }
            }
            .padding(.top, 28)
            .padding(.horizontal, 26)

            Rectangle()
                .fill(Color.black.opacity(0.9))
                .frame(height: 2)
                .padding(.top, 20)
                .padding(.horizontal, 26)

            VStack(alignment: .leading, spacing: 18) {
                Text("Preset for \(selectedPreset.title)")
                    .font(.custom("Itim", size: 24))
                    .fontWeight(.bold)
                    .foregroundStyle(.black)

                VStack(spacing: 8) {
                    ForEach(selectedPreset.categories, id: \.self) { category in
                        CategoryRow(
                            title: category,
                            isSelected: selectedCategories[selectedPreset, default: []].contains(category)
                        ) {
                            toggleCategory(category)
                        }
                    }
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 26)

            Spacer()

            Button {
                addNewPresetItem()
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private func toggleCategory(_ category: String) {
        var categories = selectedCategories[selectedPreset, default: []]

        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }

        selectedCategories[selectedPreset] = categories
    }

    private func selectAllCategories() {
        selectedCategories[selectedPreset] = Set(selectedPreset.categories)
    }

    private func addNewPresetItem() {
        if let firstCategory = selectedPreset.categories.first {
            selectedCategories[selectedPreset, default: []].insert(firstCategory)
        }
    }
}

private enum PresetMode: String, CaseIterable, Identifiable {
    case driving
    case walking
    case home
    case publicPlace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving:
            return "Driving"
        case .walking:
            return "Walking"
        case .home:
            return "Home"
        case .publicPlace:
            return "Public"
        }
    }

    var iconName: String {
        switch self {
        case .driving:
            return "steeringwheel"
        case .walking:
            return "figure.walk"
        case .home:
            return "house.fill"
        case .publicPlace:
            return "speaker.wave.2.fill"
        }
    }

    var categories: [String] {
        switch self {
        case .driving:
            return ["Sirens and alarms", "Car horns", "Emergency vehicles", "Train crossings", "Motorcycles", "Tires screeching"]
        case .walking:
            return ["Crosswalk signals", "Bike bells", "Approaching cars", "People shouting", "Scooters", "Dogs barking"]
        case .home:
            return ["Doorbell", "Kitchen timer", "Smoke alarm", "Baby crying", "Glass breaking", "Appliance beeps"]
        case .publicPlace:
            return ["Name called", "Announcements", "Phone ringing", "Loud alarms", "Crowd alerts", "Security beeps"]
        }
    }
}

private struct PresetModeButton: View {
    let preset: PresetMode
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
                    .font(.custom("Itim", size: 28))
                    .fontWeight(.bold)
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
                    .font(.custom("Itim", size: 17))
                    .fontWeight(.bold)
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
}
