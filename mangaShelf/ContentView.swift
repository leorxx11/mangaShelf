//
//  ContentView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var mangaStore = MangaStore()
    @State private var selected: MainTab = .read
    @StateObject private var uiState = UIState()
    // 主题存储：system/light/dark
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue

    var body: some View {
        let theme = AppTheme(rawValue: appThemeRaw) ?? .system

        // 使用环境覆盖 + id 强制刷新，修复从显式深色切回“跟随系统”时的无效刷新
        themedRoot(theme: theme)
            .onAppear { applyWindowAppearance(for: theme) }
            .onChange(of: appThemeRaw) { _, _ in
                applyWindowAppearance(for: AppTheme(rawValue: appThemeRaw) ?? .system)
            }
    }

    // 将主体拆出，便于在不同主题分支中复用
    @ViewBuilder
    private func themedRoot(theme: AppTheme) -> some View {
        let base = VStack(spacing: 0) {
            Group {
                switch selected {
                case .read:
                    MangaShelfView()
                        .environmentObject(mangaStore)
                        .environmentObject(uiState)
                case .settings:
                    SettingsView()
                        .environmentObject(mangaStore)
                        .environmentObject(uiState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if uiState.showBottomBar {
                BottomTabBar(selected: $selected)
            }
        }

        switch theme {
        case .system:
            base.id("theme-system")
        case .light:
            base.environment(\.colorScheme, .light).id("theme-light")
        case .dark:
            base.environment(\.colorScheme, .dark).id("theme-dark")
        }
    }

    private func applyWindowAppearance(for theme: AppTheme) {
        switch theme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

#Preview {
    ContentView()
}

enum MainTab: Hashable {
    case read
    case settings
}
