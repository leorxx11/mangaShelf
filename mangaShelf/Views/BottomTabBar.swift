//
//  BottomTabBar.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/27.
//

import SwiftUI
import AppKit

struct BottomTabBar: View {
    @Binding var selected: MainTab
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                tabItem(icon: "books.vertical", title: "阅读", tab: .read)
                Spacer()
                tabItem(icon: "gearshape", title: "设置", tab: .settings)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .background(barBackground)
    }

    @ViewBuilder
    private var barBackground: some View {
        if colorScheme == .dark {
            Color.black.opacity(0.72)
        } else {
            if #available(macOS 12.0, *) {
                Rectangle().fill(.ultraThinMaterial)
            } else {
                Color(nsColor: .windowBackgroundColor)
            }
        }
    }

    @ViewBuilder
    private func tabItem(icon: String, title: String, tab: MainTab) -> some View {
        let isSelected = selected == tab
        Button(action: { selected = tab }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    StatefulPreviewWrapper(MainTab.read) { selection in
        BottomTabBar(selected: selection)
            .frame(width: 500)
    }
}

// 辅助：预览可绑定的包装器
struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    init(_ value: Value, content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View { content($value) }
}
