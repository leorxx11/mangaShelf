//
//  MangaReaderView.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import SwiftUI
import AppKit

extension Array {
    subscript(safe index: Int) -> Element? {
        return index >= 0 && index < count ? self[index] : nil
    }
}

struct MangaReaderView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var uiState: UIState
    @State private var currentManga: Manga
    let siblings: [Manga]?
    @StateObject private var pageLoader: MangaPageLoader
    @ObservedObject private var progressManager = ReadingProgressManager.shared
    @State private var scrollProgress: Double = 0.0
    @State private var currentVisiblePage: Int = 0
    @State private var isFullScreen = false
    @State private var securityRootURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var scrollResetToken: Int = 0
    
    init(manga: Manga, siblings: [Manga]? = nil) {
        self._currentManga = State(initialValue: manga)
        self.siblings = siblings
        self._pageLoader = StateObject(wrappedValue: MangaPageLoader(manga: manga))
        
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
            
            uiState.showBottomBar = false
            // 启用安全作用域访问（避免每张图片重复 start/stop 引起卡顿）
            startSecurityAccess(for: currentManga)
            
            pageLoader.loadPages()
            loadSavedProgress()
        }
        .onDisappear {
            
            uiState.showBottomBar = true
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
                                    .onAppear { 
                                        updateCurrentPage(index)
                                        pageLoader.prefetch(around: index, radius: 2)
                                    }
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(progress.currentPage, anchor: .top)
                        }
                    } else if !pageLoader.pages.isEmpty {
                        // 立即将滚动置顶（无需动画），并在下一个 runloop 再次置顶，避免长图布局更新后回弹到底部
                        DispatchQueue.main.async {
                            proxy.scrollTo(0, anchor: .top)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                            proxy.scrollTo(0, anchor: .top)
                        }
                    }
                }
                if !isFullScreen {
                    bottomProgressBar
                }
                }
                .onChange(of: scrollResetToken) { _, _ in
                    DispatchQueue.main.async {
                        proxy.scrollTo(0, anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                        proxy.scrollTo(0, anchor: .top)
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
        ZStack {
            // 左右功能区
            HStack {
                // 返回按钮
                Button("返回") { dismiss() }
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(8)
                    .buttonStyle(PlainButtonStyle())

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

            // 居中标题：从子书架进入时显示漫画名，否则显示“阅读中”
            Text(siblings == nil ? "阅读中" : currentManga.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(.bar)
        .overlay(Divider(), alignment: .bottom)
    }
    
    // 只读进度条（不可拖动跳页）
    private var bottomProgressBar: some View {
        let isDark = colorScheme == .dark
        let panelColor = isDark ? Color.black.opacity(0.82) : Color(nsColor: .windowBackgroundColor).opacity(0.92)
        let chromeBase = isDark ? Color.black.opacity(0.55) : Color.white.opacity(0.55)
        let trackBg = isDark ? Color.white.opacity(0.28) : Color.black.opacity(0.18)
        let trackFill = isDark ? Color.white.opacity(0.42) : Color.black.opacity(0.36)
        let knobFill = isDark ? Color.white : Color.black
        let knobStroke = isDark ? Color.black.opacity(0.35) : Color.white.opacity(0.35)

        return VStack(spacing: 8) {
            HStack {
                Text("阅读进度: \(Int(scrollProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.primary)

                Spacer()

                if !pageLoader.pages.isEmpty {
                    Text("\(currentVisiblePage + 1)/\(pageLoader.pages.count) 页")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }

            GeometryReader { geo in
                let inset: CGFloat = 20
                let trackHeight: CGFloat = 12
                let knobSize: CGFloat = 24
                let trackWidth = max(1, geo.size.width - inset * 2)
                let effectiveProgress = CGFloat(scrollProgress)
                let knobX = inset + trackWidth * effectiveProgress

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(chromeBase)

                    Capsule()
                        .fill(trackBg)
                        .frame(height: trackHeight)
                        .padding(.horizontal, inset)

                    Capsule()
                        .fill(trackFill)
                        .frame(width: trackWidth * effectiveProgress, height: trackHeight)
                        .padding(.leading, inset)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // 只读的“滑块”指示，无手势
                    Circle()
                        .fill(knobFill)
                        .frame(width: knobSize, height: knobSize)
                        .overlay(
                            Circle().stroke(knobStroke, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 2, x: 0, y: 0)
                        .position(x: knobX, y: geo.size.height / 2)
                }
            }
            .frame(height: 44)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(panelColor)
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
        
        
    }
    
    private func loadSavedProgress() {
        // 进度恢复已在ScrollViewReader的onAppear中处理
        if let progress = progressManager.getProgress(for: currentManga) {
            currentVisiblePage = progress.currentPage
            scrollProgress = Double(progress.currentPage) / Double(max(1, progress.totalPages - 1))
            
        }
    }
    
    private func saveProgress() {
        // 进度保存已在updateScrollProgress中处理
        
    }

    private func switchToManga(_ newManga: Manga) {
        // 切换前停止现有安全作用域访问
        stopSecurityAccess()
        currentVisiblePage = 0
        scrollProgress = 0
        currentManga = newManga
        startSecurityAccess(for: newManga)
        pageLoader.setManga(newManga)
        // 请求置顶滚动
        scrollResetToken &+= 1
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

// 已删除 ReaderProgressSlider 的拖动手势版本，避免误触引发跳页

#Preview {
    MangaReaderView(manga: Manga(
        title: "测试漫画",
        type: .folder,
        path: URL(fileURLWithPath: "/test")
    ))
}
