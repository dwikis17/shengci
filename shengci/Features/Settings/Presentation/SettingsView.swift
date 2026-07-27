//
//  SettingsView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("selectedHSKLevel") private var selectedHSKLevel: Int = 1
    
    struct HSKLevelOption: Identifiable {
        let id: Int
        let title: String
        let description: String
        let badgeColor: Color
    }
    
    private let hskLevels: [HSKLevelOption] = [
        HSKLevelOption(id: 1, title: "HSK Level 1", description: "Beginner level (~500 exclusive words)", badgeColor: .cyan),
        HSKLevelOption(id: 2, title: "HSK Level 2", description: "Elementary level (~1,270 exclusive words)", badgeColor: .teal),
        HSKLevelOption(id: 3, title: "HSK Level 3", description: "Pre-Intermediate level (~970 exclusive words)", badgeColor: .green),
        HSKLevelOption(id: 4, title: "HSK Level 4", description: "Intermediate level (~1,000 exclusive words)", badgeColor: .yellow),
        HSKLevelOption(id: 5, title: "HSK Level 5", description: "Upper-Intermediate level (~1,070 exclusive words)", badgeColor: .orange),
        HSKLevelOption(id: 6, title: "HSK Level 6", description: "Advanced level (~1,140 exclusive words)", badgeColor: .red),
        HSKLevelOption(id: 7, title: "HSK Level 7-9", description: "Mastery / Professional level (~5,630 exclusive words)", badgeColor: .purple)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.07, green: 0.09, blue: 0.15),
                        Color(red: 0.12, green: 0.10, blue: 0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Section Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HSK Level (Exclusive)")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Select an HSK 3.0 level to update the vocabulary card feed.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Level Options List
                        VStack(spacing: 12) {
                            ForEach(hskLevels) { levelOption in
                                Button {
                                    withAnimation(.easeInOut) {
                                        selectedHSKLevel = levelOption.id
                                    }
                                } label: {
                                    HStack(spacing: 16) {
                                        // Badge Icon
                                        ZStack {
                                            Circle()
                                                .fill(levelOption.badgeColor.opacity(0.2))
                                                .frame(width: 44, height: 44)
                                            
                                            Text("\(levelOption.id == 7 ? "7-9" : "\(levelOption.id)")")
                                                .font(.headline.bold())
                                                .foregroundColor(levelOption.badgeColor)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(levelOption.title)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                            
                                            Text(levelOption.description)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.65))
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedHSKLevel == levelOption.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(Color(red: 0.25, green: 0.82, blue: 0.98))
                                        }
                                    }
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(
                                                selectedHSKLevel == levelOption.id
                                                ? Color.white.opacity(0.12)
                                                : Color.white.opacity(0.05)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(
                                                        selectedHSKLevel == levelOption.id
                                                        ? Color(red: 0.25, green: 0.82, blue: 0.98).opacity(0.6)
                                                        : Color.white.opacity(0.1),
                                                        lineWidth: 1
                                                    )
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // About Section Card
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(Color(red: 0.25, green: 0.82, blue: 0.98))
                                Text("About Wordlists")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            
                            Text("Exclusive wordlists contain words unique to each HSK level without repeating words from lower levels. HSK 7-9 covers advanced vocabulary under HSK 3.0 standards.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.07, green: 0.09, blue: 0.15), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

#Preview {
    SettingsView()
}
