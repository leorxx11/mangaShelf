//
//  AppTopBar.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/17.
//

import SwiftUI
import AppKit

struct AppTopBar<Trailing: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String?
    let showBack: Bool
    let onBack: (() -> Void)?
    let trailing: Trailing

    init(title: String? = nil, showBack: Bool = false, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.showBack = showBack
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                if showBack {
                    Button("返回") { onBack?() }
                }
                Spacer()
                trailing
            }
            if let title = title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
        }
        .frame(height: 36)
        .padding(.horizontal)
        // 深色下避免系统 .bar 偏亮，手动压暗
        .background(colorScheme == .dark ? Color.black.opacity(0.72) : Color(nsColor: .windowBackgroundColor))
        .overlay(Divider().opacity(colorScheme == .dark ? 0.35 : 1), alignment: .bottom)
    }
}

extension AppTopBar where Trailing == EmptyView {
    init(title: String? = nil, showBack: Bool = false, onBack: (() -> Void)? = nil) {
        self.init(title: title, showBack: showBack, onBack: onBack) { EmptyView() }
    }
}
