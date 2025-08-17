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
    let manga: Manga
    @StateObject private var pageLoader: MangaPageLoader
    @ObservedObject private var progressManager = ReadingProgressManager.shared
    @State private var scrollProgress: Double = 0.0
    @State private var currentVisiblePage: Int = 0
    @State private var isFullScreen = false
    @Environment(\.dismiss) private var dismiss
    
    init(manga: Manga) {
        self.manga = manga
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
                    let _ = print("📖 🔄 显示加载视图")
                    loadingView
                } else if let errorMessage = pageLoader.errorMessage {
                    let _ = print("📖 ❌ 显示错误视图: \(errorMessage)")
                    errorView(errorMessage)
                } else if pageLoader.pages.isEmpty {
                    let _ = print("📖 📭 显示空视图 - 没有页面")
                    emptyView
                } else {
                    let _ = print("📖 📚 显示内容视图 - \(pageLoader.pages.count) 页")
                    webtoonReaderContent(geometry: geometry)
                }
            }
        }
        // 隐藏系统导航栏标题（不使用新 API）
        .navigationTitle("")
        // 隐藏系统返回箭头，使用自定义顶部栏返回
        .navigationBarBackButtonHidden(true)
        .onAppear {
            print("📖 🚀 MangaReaderView.onAppear - 开始加载: \(manga.title)")
            print("📖 漫画类型: \(manga.type)")
            print("📖 漫画路径: \(manga.path.path)")
            print("📖 根目录: \(manga.rootURL?.path ?? "nil")")
            print("📖 页面加载器状态 - isLoading: \(pageLoader.isLoading), pages: \(pageLoader.pages.count), error: \(pageLoader.errorMessage ?? "nil")")
            
            pageLoader.loadPages()
            loadSavedProgress()
        }
        .onDisappear {
            print("📖 👋 MangaReaderView.onDisappear - 退出阅读: \(manga.title)")
            saveProgress()
        }
        // 键盘事件暂不处理，避免低版本 API 报错
    }
    
    private func webtoonReaderContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if !isFullScreen {
                topToolbar
            }
            
            ScrollViewReader { proxy in
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
                                        print("📖 显示第 \(index + 1) 页，图片尺寸: \(image.size)，计算高度: \(calculatedHeight)")
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
                                    .onAppear {
                                        print("📖 ❌ 第 \(index + 1) 页加载失败")
                                        if let page = pageLoader.pages[safe: index] {
                                            print("📖 失败页面路径: \(page.path)")
                                            print("📖 是否有数据: \(page.data != nil)")
                                            print("📖 是否有URL: \(page.url != nil)")
                                        }
                                        updateCurrentPage(index)
                                    }
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
                    if let progress = progressManager.getProgress(for: manga) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(progress.currentPage, anchor: .top)
                        }
                    }
                }
            }
            
            if !isFullScreen {
                bottomProgressBar
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
            Text("\(manga.title)")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // 全屏按钮
            Button(isFullScreen ? "退出全屏" : "全屏") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isFullScreen.toggle()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }
    
    private var bottomProgressBar: some View {
        VStack(spacing: 4) {
            HStack {
                Text("阅读进度: \(Int(scrollProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Spacer()
                
                if !pageLoader.pages.isEmpty {
                    Text("\(pageLoader.pages.count) 页")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            
            ProgressView(value: scrollProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                .background(Color.white.opacity(0.3))
        }
        .padding()
        .background(Color.black.opacity(0.8))
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
            for: manga,
            currentPage: pageIndex,
            totalPages: pageLoader.pages.count
        )
        
        print("📚 更新阅读进度: 第 \(pageIndex + 1) 页 / \(pageLoader.pages.count) 页 (\(Int(scrollProgress * 100))%)")
    }
    
    private func loadSavedProgress() {
        // 进度恢复已在ScrollViewReader的onAppear中处理
        if let progress = progressManager.getProgress(for: manga) {
            currentVisiblePage = progress.currentPage
            scrollProgress = Double(progress.currentPage) / Double(max(1, progress.totalPages - 1))
            print("📚 加载保存的阅读进度: 第 \(progress.currentPage + 1) 页")
        }
    }
    
    private func saveProgress() {
        // 进度保存已在updateScrollProgress中处理
        print("📚 保存阅读进度")
    }
}

#Preview {
    MangaReaderView(manga: Manga(
        title: "测试漫画",
        type: .folder,
        path: URL(fileURLWithPath: "/test")
    ))
}
