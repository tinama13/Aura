//
//  NavBar.swift
//  Aura
//
//  Created by Tina Ma on 7/8/26.
//

import SwiftUI

struct NavBar: View {
    @Binding var current_tab: Tab
    
    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.rawValue) {
                tab in
                
                Spacer()
                
                Button (action: {
                    current_tab = tab
                }) {
                    VStack {
                        Image(systemName: tab.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(current_tab == tab ? Color.purple.opacity(0.15) : Color.clear)
                            )
                        
                        Text(tab.rawValue)
                            .font(.custom("MarkerFelt-Thin", size: 11))
                            .foregroundColor(.black.opacity(0.7))
                    }
                }
                
                Spacer()
            }
        }
        
        .padding(.top, 12)
        .padding(.bottom, 30)
        .background(Color(red: 0.88, green: 0.93, blue: 0.96))
    }
}

#Preview {
    NavBar(current_tab: .constant(.home))
}
