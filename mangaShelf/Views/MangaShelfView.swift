//
//  MangaShelfView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI
import AppKit

struct MangaShelfView: View {
    @EnvironmentObject private var mangaStore: MangaStore
    @EnvironmentObject private var uiState: UIState
    // 选中项改为直接使用 NavigationLink，不再需要选中状态
    // 保留占位，若后续需要可恢复
    // @State private var selectedManga: Manga?
    // 使用可见的 NavigationLink 导航，不再用 .sheet
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack(path: $uiState.shelfPath) {
            VStack {
                // 顶部操作栏：统一标题
                AppTopBar(title: "书架", showBack: false) { EmptyView() }

                if mangaStore.mangas.isEmpty {
                    emptyStateView
                } else {
                    mangaGridView
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            // 隐藏系统导航栏标题，统一使用自定义上边栏（尽量不使用新API）
            .navigationTitle("")
            .navigationDestination(for: ShelfRoute.self) { route in
                switch route {
                case .subShelf(let m):
                    SubShelfView(seriesManga: m)
                case .read(let m):
                    MangaReaderView(manga: m)
                }
            }
            .navigationTransition(.automatic)
            .onChange(of: mangaStore.mangas.count) { _, newCount in
                if newCount == 0 { uiState.shelfPath.removeAll() }
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

            Text("请在底部‘设置’页选择目录导入漫画")
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
                        NavigationLink(value: ShelfRoute.subShelf(manga)) {
                            MangaCardView(manga: manga)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                mangaStore.deleteManga(manga)
                            }
                        }
                        .onAppear { }
                    } else {
                        NavigationLink(value: ShelfRoute.read(manga)) {
                            MangaCardView(manga: manga)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("删除", role: .destructive) {
                                mangaStore.deleteManga(manga)
                            }
                        }
                        .onAppear { }
                    }
                }
            }
            .padding()
        }
    }
    

}

// 使用 NavigationStack 路由的目标类型
// 已迁移到 Models/ShelfRoute.swift 以便跨视图共享

struct MangaCardView: View {
    let manga: Manga
    @ObservedObject private var progressManager = ReadingProgressManager.shared
    @State private var thumbImage: NSImage?
    @State private var isLoadingThumb = false
    
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
        if let img = thumbImage {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 160)
                .clipped()
                .cornerRadius(8)
        } else if let coverPath = manga.coverImagePath {
            // 优先使用已缓存缩略图（针对 .image/大图）
            if manga.type == .image,
               let cached = ImageCacheManager.shared.getCachedThumbnail(for: coverPath, maxPixel: 320),
               let thumb = ImageDecode.fromURL(cached) {
                Image(nsImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 160)
                    .clipped()
                    .cornerRadius(8)
                    .onAppear { self.thumbImage = thumb }
            } else if let nsImage = loadImage(from: coverPath, rootURL: manga.rootURL) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 160)
                    .clipped()
                    .cornerRadius(8)
                    .onAppear { self.thumbImage = nsImage }
            } else {
                placeholderAndMaybeGenerate()
            }
        } else {
            VStack {
                let iconName: String = {
                    switch manga.type {
                    case .series: return "folder.fill"
                    case .zip:    return "book.closed"
                    case .image:  return "photo"
                    case .folder: return "folder"
                    }
                }()
                Image(systemName: iconName)
                    .font(.system(size: 40))
                    .foregroundColor(manga.type == .series ? .blue : .gray)

                let label: String = {
                    switch manga.type {
                    case .zip: return "ZIP"
                    case .series: return "系列"
                    case .image: return "图片"
                    case .folder: return "文件夹"
                    }
                }()
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120, height: 160)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .onAppear {
                if manga.type == .image, let path = manga.coverImagePath {
                    generateThumbIfNeeded(for: path, rootURL: manga.rootURL)
                }
            }
        }
    }

    @ViewBuilder
    private func placeholderAndMaybeGenerate() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.1))
            .frame(width: 120, height: 160)
            .overlay(Image(systemName: "photo").font(.system(size: 34)).foregroundColor(.gray))
            .cornerRadius(8)
            .onAppear {
                if manga.type == .image, let path = manga.coverImagePath {
                    generateThumbIfNeeded(for: path, rootURL: manga.rootURL)
                }
            }
    }

    private func generateThumbIfNeeded(for path: URL, rootURL: URL?) {
        guard !isLoadingThumb else { return }
        if let cached = ImageCacheManager.shared.getCachedThumbnail(for: path, maxPixel: 320),
           let img = ImageDecode.fromURL(cached) {
            self.thumbImage = img
            return
        }
        isLoadingThumb = true
        // 访问权限处理
        var effectiveRoot = rootURL
        if effectiveRoot == nil && !path.path.contains("/Caches/") {
            if path.path.contains("/Documents/comic/") {
                effectiveRoot = URL(fileURLWithPath: "/Users/leo/Documents/comic")
            }
        }
        let rootForTask = effectiveRoot
        let key = path.path + "_320"
        Task { await ThumbGenerator.shared.generate(key: key) {
            let accessed = (rootForTask?.startAccessingSecurityScopedResource() == true)
            defer { if accessed, let r = rootForTask { r.stopAccessingSecurityScopedResource() } }
            if let data = ImageDecode.thumbnailData(fromFile: path, maxPixel: 320),
               let cachedURL = ImageCacheManager.shared.cacheThumbnail(data, for: path, maxPixel: 320) {
                await MainActor.run {
                    if let img = ImageDecode.fromURL(cachedURL) {
                        self.thumbImage = img
                    }
                    self.isLoadingThumb = false
                }
            } else {
                await MainActor.run { self.isLoadingThumb = false }
            }
        }}
    }
    
    private func loadImage(from url: URL, rootURL: URL?) -> NSImage? {
        
        
        // 检查是否是缓存图片（不需要安全作用域访问）
        let isCachedImage = url.path.contains("/Caches/MangaCovers/")
        
        // 如果rootURL为nil，尝试从图片路径推断根目录
        var effectiveRootURL = rootURL
        if effectiveRootURL == nil && !isCachedImage {
            // 假设根目录是Documents/comic
            if url.path.contains("/Documents/comic/") {
                let comicPath = "/Users/leo/Documents/comic"
                effectiveRootURL = URL(fileURLWithPath: comicPath)
                
            }
        }
        
        // 如果不是缓存图片且有根目录URL，启用安全作用域访问
        let hasAccess = !isCachedImage && effectiveRootURL?.startAccessingSecurityScopedResource() == true
        // no-op
        
        defer {
            if hasAccess {
                effectiveRootURL?.stopAccessingSecurityScopedResource()
            }
        }
        
        if let img = ImageDecode.fromURL(url) {
            return img
        }
        do {
            let data = try Data(contentsOf: url)
            return ImageDecode.fromData(data)
        } catch {
            print("读取封面图片失败: \(error)")
            return nil
        }
    }
}

#Preview {
    MangaShelfView().environmentObject(MangaStore())
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
