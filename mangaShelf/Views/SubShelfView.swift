//
//  SubShelfView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI
import AppKit

struct SubShelfView: View {
    let seriesManga: Manga
    @Environment(\.dismiss) private var dismiss
        
    init(seriesManga: Manga) {
        self.seriesManga = seriesManga
        
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]
    
    var body: some View {
        VStack {
            // 统一高度的上边栏，包含返回与标题
            AppTopBar(title: seriesManga.title, showBack: true, onBack: {
                dismiss()
            }) { EmptyView() }

            if let subMangas = seriesManga.subMangas, !subMangas.isEmpty {
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(subMangas) { manga in
                            NavigationLink {
                                MangaReaderView(manga: manga, siblings: subMangas)
                            } label: {
                                MangaCardView(manga: manga)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(PlainButtonStyle())

                        }
                    }
                    .padding()
                }
            } else {
                
                emptyStateView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // 隐藏系统导航栏标题（不使用新 API）
        .navigationTitle("")
        // 隐藏系统返回箭头，使用自定义顶部栏返回
        .navigationBarBackButtonHidden(true)
        .applyNavSlide()
        .onAppear {
            
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("此系列暂无漫画")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("该系列文件夹中没有找到有效的漫画文件")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SubShelfView(seriesManga: Manga(
        title: "测试系列",
        type: .series,
        path: URL(fileURLWithPath: "/test"),
        subMangas: []
    ))
}

// MARK: - Nav slide helper (macOS 14+)
fileprivate extension View {
    @ViewBuilder func applyNavSlide() -> some View {
        if #available(macOS 14.0, *) {
            self.navigationTransition(.automatic)
        } else {
            self
        }
    }
}
