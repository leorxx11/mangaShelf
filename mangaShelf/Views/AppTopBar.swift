//
//  AppTopBar.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/17.
//

import SwiftUI

struct AppTopBar<Trailing: View>: View {
    let showBack: Bool
    let onBack: (() -> Void)?
    let trailing: Trailing

    init(showBack: Bool = false, onBack: (() -> Void)? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.showBack = showBack
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button("返回") { onBack?() }
            } else {
                // 占位保持左右对称
                Color.clear.frame(width: 0, height: 0)
            }

            Spacer()

            trailing
        }
        .frame(height: 44)
        .padding(.horizontal)
    }
}

extension AppTopBar where Trailing == EmptyView {
    init(showBack: Bool = false, onBack: (() -> Void)? = nil) {
        self.init(showBack: showBack, onBack: onBack) { EmptyView() }
    }
}

