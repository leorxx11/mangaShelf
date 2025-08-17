//
//  SubShelfView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI

struct SubShelfView: View {
    let seriesManga: Manga
    @Environment(\.dismiss) private var dismiss
        
    init(seriesManga: Manga) {
        self.seriesManga = seriesManga
        print("📚 🏗️ 创建SubShelfView - 系列: \(seriesManga.title)")
        print("📚 系列类型: \(seriesManga.type)")
        print("📚 系列路径: \(seriesManga.path.path)")
        print("📚 根目录: \(seriesManga.rootURL?.path ?? "nil")")
        print("📚 子漫画数量: \(seriesManga.subMangas?.count ?? 0)")
        print("📚 isSeries: \(seriesManga.isSeries)")
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]
    
    var body: some View {
        VStack {
            // 统一高度的上边栏，包含返回按钮
            AppTopBar(showBack: true, onBack: {
                print("🔙 SubShelf 顶部栏返回被点击")
                dismiss()
            }) { EmptyView() }

            if let subMangas = seriesManga.subMangas, !subMangas.isEmpty {
                let _ = print("📚 📖 显示系列内容 - 共 \(subMangas.count) 个子漫画")
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(subMangas) { manga in
                            NavigationLink {
                                MangaReaderView(manga: manga)
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
                let _ = print("📚 📭 显示空状态 - 没有子漫画")
                emptyStateView
            }
        }
        // 隐藏系统导航栏标题（不使用新 API）
        .navigationTitle("")
        // 隐藏系统返回箭头，使用自定义顶部栏返回
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("📚 🚀 SubShelfView.onAppear - 系列: \(seriesManga.title)")
            print("📚 子漫画数量: \(seriesManga.subMangas?.count ?? 0)")
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
