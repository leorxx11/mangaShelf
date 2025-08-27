//
//  MangaReaderView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI

extension Array {
    subscript(safe index: Int) -> Element? {
        return index >= 0 && index < count ? self[index] : nil
    }
}

struct MangaReaderView: View {
    @State private var currentManga: Manga
    let siblings: [Manga]?
    @StateObject private var pageLoader: MangaPageLoader
    @ObservedObject private var progressManager = ReadingProgressManager.shared
    @State private var scrollProgress: Double = 0.0
    @State private var currentVisiblePage: Int = 0
    @State private var isFullScreen = false
    @State private var securityRootURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    init(manga: Manga, siblings: [Manga]? = nil) {
        self._currentManga = State(initialValue: manga)
        self.siblings = siblings
        self._pageLoader = StateObject(wrappedValue: MangaPageLoader(manga: manga))
        print("📖 🎬 创建MangaReaderView - 漫画: \(manga.title)")
        print("📖 漫画类型: \(manga.type)")
        print("📖 漫画路径: \(manga.path.path)")
        print("📖 根目录: \(manga.rootURL?.path ?? "nil")")
        print("📖 子漫画数量: \(manga.subMangas?.count ?? 0)")
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()


                if pageLoader.isLoading {
                    loadingView
                } else if let errorMessage = pageLoader.errorMessage {
                    errorView(errorMessage)
                } else if pageLoader.pages.isEmpty {
                    emptyView
                } else {
                    webtoonReaderContent(geometry: geometry)
                }
            }
        }
        // 隐藏系统导航栏标题（不使用新 API）
        .navigationTitle("")
        // 隐藏系统返回箭头，使用自定义顶部栏返回
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("📖 🚀 MangaReaderView.onAppear - 开始加载: \(currentManga.title)")
            print("📖 漫画类型: \(currentManga.type)")
            print("📖 漫画路径: \(currentManga.path.path)")
            print("📖 根目录: \(currentManga.rootURL?.path ?? "nil")")
            print("📖 页面加载器状态 - isLoading: \(pageLoader.isLoading), pages: \(pageLoader.pages.count), error: \(pageLoader.errorMessage ?? "nil")")
            // 启用安全作用域访问（避免每张图片重复 start/stop 引起卡顿）
            startSecurityAccess(for: currentManga)
            
            pageLoader.loadPages()
            loadSavedProgress()
        }
        .onDisappear {
            print("📖 👋 MangaReaderView.onDisappear - 退出阅读: \(currentManga.title)")
            saveProgress()
            // 结束安全作用域访问
            securityRootURL?.stopAccessingSecurityScopedResource()
            securityRootURL = nil
        }
        // 键盘事件暂不处理，避免低版本 API 报错
    }
    
    private func webtoonReaderContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if !isFullScreen {
                topToolbar
            }
            
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(pageLoader.pages.enumerated()), id: \.offset) { index, page in
                            if let image = pageLoader.getPageImage(at: index) {
                                let aspectRatio = image.size.width / image.size.height
                                let calculatedHeight = geometry.size.width / aspectRatio
                                
                                Image(nsImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: calculatedHeight)
                                    .clipped()
                                    .id(index)
                                    .onAppear { updateCurrentPage(index) }
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isFullScreen.toggle()
                                        }
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: geometry.size.width, height: 300)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("第 \(index + 1) 页")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text("加载失败")
                                                .font(.caption2)
                                                .foregroundColor(.red)
                                            if let page = pageLoader.pages[safe: index] {
                                                Text(page.path)
                                                    .font(.caption2)
                                                    .foregroundColor(.gray)
                                                    .lineLimit(2)
                                            }
                                        }
                                    )
                                    .id(index)
                                    .onAppear { updateCurrentPage(index) }
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            isFullScreen.toggle()
                                        }
                                    }
                            }
                        }
                    }
                }
                .onAppear {
                    // 恢复阅读进度
                    if let progress = progressManager.getProgress(for: currentManga) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(progress.currentPage, anchor: .top)
                        }
                    }
                }
                .onReceive(pageLoader.$pages) { _ in
                    if let progress = progressManager.getProgress(for: currentManga) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(progress.currentPage, anchor: .top)
                        }
                    } else if !pageLoader.pages.isEmpty {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(0, anchor: .top)
                        }
                    }
                }
                
                if !isFullScreen {
                    bottomProgressBar(proxy: proxy)
                }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("正在加载漫画...")
                .foregroundColor(.white)
                .font(.title2)
        }
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("加载失败")
                .font(.title2)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("返回") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("没有找到图片")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("此漫画中没有找到可显示的图片文件")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("返回") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var topToolbar: some View {
        HStack {
            // 返回按钮
            Button("返回") {
                print("🔙 Reader 工具栏返回被点击 - 准备dismiss")
                dismiss()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // 漫画标题
            Text("\(currentManga.title)")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // 上/下一集切换（若有同系列）
            HStack(spacing: 8) {
                if let prev = previousManga {
                    Button {
                        switchToManga(prev)
                    } label: {
                        Text("上一集")
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let next = nextManga {
                    Button {
                        switchToManga(next)
                    } label: {
                        Text("下一集")
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private func bottomProgressBar(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("阅读进度: \(Int(scrollProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()

                if !pageLoader.pages.isEmpty {
                    // 在右侧显示“当前页/总页数”
                    Text("\(currentVisiblePage + 1)/\(pageLoader.pages.count) 页")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }

            ReaderProgressSlider(
                progress: $scrollProgress,
                totalPages: max(1, pageLoader.pages.count),
                onSeek: { targetIndex in
                    guard !pageLoader.pages.isEmpty else { return }
                    let clamped = min(max(targetIndex, 0), pageLoader.pages.count - 1)
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(clamped, anchor: .top)
                    }
                }
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.82))
    }
    
    private func updateCurrentPage(_ pageIndex: Int) {
        guard !pageLoader.pages.isEmpty else { return }
        
        // 只在页面实际变化时更新
        guard pageIndex != currentVisiblePage else { return }
        
        currentVisiblePage = pageIndex
        
        // 更新滚动进度
        scrollProgress = Double(pageIndex) / Double(max(1, pageLoader.pages.count - 1))
        
        // 保存阅读进度
        progressManager.updateProgress(
            for: currentManga,
            currentPage: pageIndex,
            totalPages: pageLoader.pages.count
        )
        
        print("📚 更新阅读进度: 第 \(pageIndex + 1) 页 / \(pageLoader.pages.count) 页 (\(Int(scrollProgress * 100))%)")
    }
    
    private func loadSavedProgress() {
        // 进度恢复已在ScrollViewReader的onAppear中处理
        if let progress = progressManager.getProgress(for: currentManga) {
            currentVisiblePage = progress.currentPage
            scrollProgress = Double(progress.currentPage) / Double(max(1, progress.totalPages - 1))
            print("📚 加载保存的阅读进度: 第 \(progress.currentPage + 1) 页")
        }
    }
    
    private func saveProgress() {
        // 进度保存已在updateScrollProgress中处理
        print("📚 保存阅读进度")
    }

    private func switchToManga(_ newManga: Manga) {
        // 切换前停止现有安全作用域访问
        stopSecurityAccess()
        currentVisiblePage = 0
        scrollProgress = 0
        currentManga = newManga
        startSecurityAccess(for: newManga)
        pageLoader.setManga(newManga)
    }

    private func startSecurityAccess(for manga: Manga) {
        var root = manga.rootURL
        if root == nil, manga.path.path.contains("/Documents/comic/") {
            root = URL(fileURLWithPath: "/Users/leo/Documents/comic")
        }
        if let root {
            if root.startAccessingSecurityScopedResource() {
                securityRootURL = root
            }
        }
    }

    private func stopSecurityAccess() {
        if let root = securityRootURL {
            root.stopAccessingSecurityScopedResource()
            securityRootURL = nil
        }
    }

    // MARK: - 同系列上一/下一集
    private var siblingIndex: Int? {
        guard let siblings else { return nil }
        // 先按 id 匹配，若失败则回退到路径匹配
        if let byId = siblings.firstIndex(where: { $0.id == currentManga.id }) {
            return byId
        }
        return siblings.firstIndex(where: { $0.path.path == currentManga.path.path })
    }

    private var previousManga: Manga? {
        guard let siblings, let idx = siblingIndex, idx > 0 else { return nil }
        return siblings[idx - 1]
    }

    private var nextManga: Manga? {
        guard let siblings, let idx = siblingIndex, idx < siblings.count - 1 else { return nil }
        return siblings[idx + 1]
    }
}

// MARK: - 自定义可拖动进度条（圆角轨道 + 圆形滑块）
private struct ReaderProgressSlider: View {
    @Binding var progress: Double   // 0...1
    let totalPages: Int
    var onSeek: (Int) -> Void

    @State private var draggingProgress: Double? = nil
    @State private var lastSentIndex: Int = -1

    private let trackHeight: CGFloat = 12
    private let knobSize: CGFloat = 24
    private let inset: CGFloat = 20  // 轨道左右内边距

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(1, geo.size.width - inset * 2)
            let effectiveProgress = CGFloat(draggingProgress ?? progress)
            let knobX = inset + trackWidth * effectiveProgress

            ZStack {
                // 外层圆角底板（更贴近参考图效果）
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.55))

                // 轨道（圆头）
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(height: trackHeight)
                    .padding(.horizontal, inset)

                // 已读进度高亮（可按需保留/去除）
                Capsule()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: trackWidth * effectiveProgress, height: trackHeight)
                    .padding(.leading, inset)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 滑块
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.35), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.6), radius: 3, x: 0, y: 0)
                    .position(x: knobX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x - inset, 0), trackWidth)
                        let p = Double(x / trackWidth)
                        draggingProgress = p
                        // 同步外部绑定，便于实时更新百分比文本
                        progress = p

                        let maxIndex = max(totalPages - 1, 0)
                        let idx = Int(round(p * Double(maxIndex)))
                        if idx != lastSentIndex {
                            lastSentIndex = idx
                            onSeek(idx)
                        }
                    }
                    .onEnded { _ in
                        if let p = draggingProgress { progress = p }
                        draggingProgress = nil
                    }
            )
        }
        .frame(height: 44)
    }
}

#Preview {
    MangaReaderView(manga: Manga(
        title: "测试漫画",
        type: .folder,
        path: URL(fileURLWithPath: "/test")
    ))
}
