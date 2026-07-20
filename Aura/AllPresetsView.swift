//
//  AllPresetsView.swift
//  Aura
//

import SwiftUI

struct AllPresetsView: View {
    @EnvironmentObject var presetManager: PresetManager
    @Environment(\.dismiss) var dismiss
    
    @State private var showLimitError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AuraHeaderView()
                
                List {
                    Section(
                        header: Text("Select up to 4 favorites to show on the main screen. (\(presetManager.presets.filter({ $0.isFavorite }).count)/4)"),
                        
                        footer: Group {
                            if showLimitError {
                                Text("You can only select up to 4 favorites.")
                                    .foregroundColor(.red)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.top, 4)
                                    .transition(.opacity)
                            }
                        }
                    ) {
                        ForEach(presetManager.presets) { preset in
                            HStack(spacing: 16) {
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 20))
                                    .frame(width: 30)
                                    .foregroundColor(.black)
                                
                                Text(preset.title)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                if preset.isFavorite {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(Color(red: 0.204, green: 0.678, blue: 0.914))
                                        .font(.system(size: 20))
                                } else {
                                    Image(systemName: "star")
                                        .foregroundColor(.gray.opacity(0.4))
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                let success = presetManager.toggleFavorite(presetID: preset.id)
                                
                                withAnimation {
                                    if !success {
                                        showLimitError = true
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                            withAnimation { showLimitError = false }
                                        }
                                    } else {
                                        showLimitError = false
                                    }
                                    
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("All Presets")
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
    AllPresetsView()
        .environmentObject(PresetManager())
}
