//
//  MangaShelfView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct MangaShelfView: View {
    @StateObject private var mangaStore = MangaStore()
    @State private var isShowingDirectoryPicker = false
    // 选中项改为直接使用 NavigationLink，不再需要选中状态
    // 保留占位，若后续需要可恢复
    // @State private var selectedManga: Manga?
    // 使用可见的 NavigationLink 导航，不再用 .sheet
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            VStack {
                // 顶部操作栏：清除 / 导入（统一高度）
                AppTopBar(showBack: false) {
                    HStack(spacing: 12) {
                        Button("清除") {
                            mangaStore.clearMangas()
                            ImageCacheManager.shared.clearCache()
                        }
                        .disabled(mangaStore.mangas.isEmpty)

                        Button("导入") {
                            print("🔥 导入按钮被点击")
                            isShowingDirectoryPicker = true
                            print("🔥 isShowingDirectoryPicker设置为: \(isShowingDirectoryPicker)")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if mangaStore.mangas.isEmpty {
                    emptyStateView
                } else {
                    mangaGridView
                }
            }
            // 隐藏系统导航栏标题，统一使用自定义上边栏（尽量不使用新API）
            .navigationTitle("")

            .fileImporter(
                isPresented: $isShowingDirectoryPicker,
                allowedContentTypes: [UTType.folder],
                allowsMultipleSelection: false
            ) { result in
                print("🔥 fileImporter 回调被触发")
                handleDirectorySelection(result)
            }
        }
        // 取消 .sheet 弹出方式
    }

    // 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("书架是空的")
                .font(.title2)
                .foregroundColor(.gray)

            Text("点击上方的\"导入\"按钮选择漫画目录")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    
    private var mangaGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(mangaStore.mangas) { manga in
                    if manga.isSeries {
                        NavigationLink {
                            SubShelfView(seriesManga: manga)
                        } label: {
                            MangaCardView(manga: manga)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                print("🗑️ 删除系列漫画: \(manga.title)")
                                mangaStore.deleteManga(manga)
                            }
                        }
                        .onAppear {
                            print("🎨 显示系列漫画: \(manga.title), 类型: \(manga.type), isSeries: \(manga.isSeries), 子漫画数量: \(manga.subMangas?.count ?? 0)")
                        }
                    } else {
                        NavigationLink {
                            MangaReaderView(manga: manga)
                        } label: {
                            MangaCardView(manga: manga)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                print("🗑️ 删除漫画: \(manga.title)")
                                mangaStore.deleteManga(manga)
                            }
                        }
                        .onAppear {
                            print("🎨 显示普通漫画: \(manga.title), 类型: \(manga.type)")
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func handleDirectorySelection(_ result: Result<[URL], Error>) {
        print("🔥 handleDirectorySelection 被调用")
        switch result {
        case .success(let urls):
            print("🔥 选择文件成功，URL数量: \(urls.count)")
            guard let selectedURL = urls.first else { 
                print("🔥 没有选择任何URL")
                return 
            }
            print("🔥 选择的目录: \(selectedURL.path)")
            
            // 启用安全作用域访问
            guard selectedURL.startAccessingSecurityScopedResource() else {
                print("🔥 无法启用安全作用域访问")
                return
            }
            print("🔥 安全作用域访问已启用")
            
            Task {
                print("🔥 开始扫描目录...")
                let scannedMangas = MangaScanner.scanDirectory(at: selectedURL)
                print("🔥 扫描到 \(scannedMangas.count) 个漫画")
                
                await MainActor.run {
                    print("🔥 设置新的漫画列表，总数: \(scannedMangas.count)")
                    mangaStore.setMangas(scannedMangas)
                    print("🔥 漫画设置完成，总数: \(mangaStore.mangas.count)")
                }
                
                // 停止安全作用域访问
                selectedURL.stopAccessingSecurityScopedResource()
                print("🔥 安全作用域访问已停止")
            }
            
        case .failure(let error):
            print("🔥 选择目录失败: \(error)")
    }
    
}

}

struct MangaCardView: View {
    let manga: Manga
    @ObservedObject private var progressManager = ReadingProgressManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                coverImageView
                    .frame(width: 120, height: 160)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                if let progress = progressManager.getProgress(for: manga) {
                    progressIndicator(progress)
                }
            }
            
            Text(manga.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(width: 120)
    }
    
    @ViewBuilder
    private func progressIndicator(_ progress: ReadingProgress) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .frame(height: 2)
                .foregroundColor(.blue.opacity(0.3))
                .overlay(
                    HStack {
                        Rectangle()
                            .frame(width: 120 * progress.progressPercentage / 100, height: 2)
                            .foregroundColor(.blue)
                        Spacer(minLength: 0)
                    },
                    alignment: .leading
                )
            
            if progress.isCompleted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Text("已完成")
                        .font(.caption2)
                        .foregroundColor(.green)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
            } else {
                HStack {
                    Text("\(progress.currentPage + 1)/\(progress.totalPages)")
                        .font(.caption2)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
            }
        }
        .cornerRadius(8, corners: [.bottomLeft, .bottomRight])
    }
    
    @ViewBuilder
    private var coverImageView: some View {
        if let coverPath = manga.coverImagePath,
           let nsImage = loadImage(from: coverPath, rootURL: manga.rootURL) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 160)
                .clipped()
                .cornerRadius(8)
        } else {
            VStack {
                Image(systemName: manga.type == .series ? "folder.fill" : "book.closed")
                    .font(.system(size: 40))
                    .foregroundColor(manga.type == .series ? .blue : .gray)
                
                Text(manga.type == .zip ? "ZIP" : manga.type == .series ? "系列" : "文件夹")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 160)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private func loadImage(from url: URL, rootURL: URL?) -> NSImage? {
        print("🖼️ 尝试加载图片: \(url.path)")
        print("🖼️ rootURL: \(rootURL?.path ?? "nil")")
        
        // 检查是否是缓存图片（不需要安全作用域访问）
        let isCachedImage = url.path.contains("/Caches/MangaCovers/")
        
        // 如果rootURL为nil，尝试从图片路径推断根目录
        var effectiveRootURL = rootURL
        if effectiveRootURL == nil && !isCachedImage {
            // 假设根目录是Documents/comic
            if url.path.contains("/Documents/comic/") {
                let comicPath = "/Users/leo/Documents/comic"
                effectiveRootURL = URL(fileURLWithPath: comicPath)
                print("🖼️ 推断根目录: \(comicPath)")
            }
        }
        
        // 如果不是缓存图片且有根目录URL，启用安全作用域访问
        let hasAccess = !isCachedImage && effectiveRootURL?.startAccessingSecurityScopedResource() == true
        if hasAccess {
            print("🖼️ 安全作用域访问已启用")
        } else if isCachedImage {
            print("🖼️ 加载缓存图片，无需安全作用域访问")
        } else {
            print("🖼️ 未启用安全作用域访问")
        }
        
        defer {
            if hasAccess {
                effectiveRootURL?.stopAccessingSecurityScopedResource()
                print("🖼️ 安全作用域访问已停止")
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            print("🖼️ 成功读取图片数据，大小: \(data.count) 字节")
            
            guard let nsImage = NSImage(data: data) else {
                print("🖼️ ❌ 无法从数据创建NSImage")
                return nil
            }
            
            print("🖼️ ✅ 成功创建NSImage，尺寸: \(nsImage.size)")
            return nsImage
        } catch {
            print("🖼️ ❌ 读取图片数据失败: \(error)")
            return nil
        }
    }
}

#Preview {
    MangaShelfView()
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight, startAngle: Angle.degrees(-90), endAngle: Angle.degrees(0), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight, startAngle: Angle.degrees(0), endAngle: Angle.degrees(90), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft, startAngle: Angle.degrees(90), endAngle: Angle.degrees(180), clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft, startAngle: Angle.degrees(180), endAngle: Angle.degrees(270), clockwise: false)
        }
        path.closeSubpath()
        
        return path
    }
}
