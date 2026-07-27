//
//  ContentView.swift
//  shengci
//
//  Created by Dwiki on 27/07/26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab: Hashable {
        case home
        case search
        case saved
        case settings
    }
    
    init() {
        // Customize TabBar appearance for sleek dark theme
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 0.95)
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Learn", systemImage: "play.rectangle.fill")
                }
                .tag(Tab.home)
            
            PlaceholderTabView(
                title: "Vocabulary Search",
                icon: "magnifyingglass",
                description: "Search HSK words by Pinyin, English, or Chinese characters."
            )
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(Tab.search)
            
            PlaceholderTabView(
                title: "Saved Words",
                icon: "heart.fill",
                description: "Review your saved vocabulary cards."
            )
            .tabItem {
                Label("Saved", systemImage: "heart.fill")
            }
            .tag(Tab.saved)
            
            PlaceholderTabView(
                title: "Settings",
                icon: "gearshape.fill",
                description: "Manage HSK levels, audio rate, and display options."
            )
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
            .tag(Tab.settings)
        }
        .tint(Color(red: 0.25, green: 0.82, blue: 0.98)) // Cyan accent tint
    }
}

// MARK: - Placeholder Tab View
struct PlaceholderTabView: View {
    let title: String
    let icon: String
    let description: String
    
    var body: some View {
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
            
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0.25, green: 0.82, blue: 0.98))
                
                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

#Preview {
    ContentView()
}
