//
//  TransferManagerView.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/29.
//

import SwiftUI

struct TransferManagerView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(title: "传输管理", showBack: true) { dismiss() }
            List {
                Section {
                    Text("传输管理（开发中）")
                        .foregroundColor(.secondary)
                } header: {
                    Text("传输")
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("")
    }
}

#Preview {
    TransferManagerView()
}
