//
//  MangaPageLoader.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation
import AppKit
 

struct MangaPage {
    let index: Int
    let path: String
    let url: URL?
    let data: Data?
    
    init(index: Int, path: String, url: URL? = nil, data: Data? = nil) {
        self.index = index
        self.path = path
        self.url = url
        self.data = data
    }
}

class MangaPageLoader: ObservableObject {
    @Published var pages: [MangaPage] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var manga: Manga
    private let memoryCache = NSCache<NSString, NSImage>()
    private let prefetchTracker = PrefetchTracker()
    
    init(manga: Manga) {
        self.manga = manga
        memoryCache.countLimit = 150
        
    }
    
    func setManga(_ newManga: Manga) {
        
        self.manga = newManga
        self.pages = []
        self.errorMessage = nil
        self.isLoading = false
        loadPages()
    }

    func loadPages() {
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                // 加载页面为同步操作，这里无需使用 await
                let loadedPages = try loadPagesAsync()
                await MainActor.run {
                    self.pages = loadedPages
                    self.isLoading = false
                    
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    
                }
            }
        }
    }
    
    private func loadPagesAsync() throws -> [MangaPage] {
        switch manga.type {
        case .folder:
            return try loadPagesFromFolder()
        case .zip:
            return try loadPagesFromZip()
        case .image:
            return try loadPagesFromSingleImage()
        case .series:
            throw MangaPageLoaderError.seriesNotSupported
        }
    }
    
    private func loadPagesFromFolder() throws -> [MangaPage] {
        
        // 安全作用域访问由 View 层统一控制，这里不再 start/stop
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: manga.path, includingPropertiesForKeys: [.nameKey])
        
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
        let imageFiles = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }.sorted { url1, url2 in
            return url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
        }
        
        
        
        return imageFiles.enumerated().map { index, url in
            MangaPage(index: index, path: url.lastPathComponent, url: url)
        }
    }
    
    private func loadPagesFromZip() throws -> [MangaPage] {
        
        // 仅枚举条目，不解压数据
        let paths = ZipManager.listImageEntryPaths(in: manga.path)
        

        return paths.enumerated().map { index, path in
            MangaPage(index: index, path: path, url: nil, data: nil)
        }
    }

    private func loadPagesFromSingleImage() throws -> [MangaPage] {
        let url = manga.path
        return [MangaPage(index: 0, path: url.lastPathComponent, url: url)]
    }
    
    func getPageImage(at index: Int) -> NSImage? {
        guard index >= 0 && index < pages.count else {
            
            return nil
        }
        
        let page = pages[index]
        let cacheKey = page.path as NSString
        if let cached = memoryCache.object(forKey: cacheKey) {
            return cached
        }
        if let data = page.data {
            let img = NSImage(data: data)
            if let img { memoryCache.setObject(img, forKey: cacheKey) }
            return img
        } else if let url = page.url {
            let img = loadImageFromFile(url: url)
            if let img { memoryCache.setObject(img, forKey: cacheKey) }
            return img
        } else {
            // ZIP 懒加载：尝试从缓存读取，否则按需解压
            let img = loadImageFromZip(entryPath: page.path)
            if let img { memoryCache.setObject(img, forKey: cacheKey) }
            return img
        }
    }
    
    private func loadImageFromFile(url: URL) -> NSImage? {
        if let img = ImageDecode.fromURL(url) { return img }
        do { return ImageDecode.fromData(try Data(contentsOf: url)) } catch { return nil }
    }

    private func loadImageFromZip(entryPath: String) -> NSImage? {
        // 优先从磁盘缓存读取
        if let cachedURL = ImageCacheManager.shared.getCachedPage(for: manga.path, entryPath: entryPath) {
            do {
                let data = try Data(contentsOf: cachedURL)
                return NSImage(data: data)
            } catch {
                print("读取页面缓存失败: \(error)")
            }
        }

        // 未命中缓存，按需从 ZIP 解压
        guard let data = ZipManager.extractImageData(from: manga.path, entryPath: entryPath) else {
            print("ZIP按需解压失败或未找到条目: \(entryPath)")
            return nil
        }
        // 写入缓存（忽略失败）
        _ = ImageCacheManager.shared.cachePageImage(data: data, for: manga.path, entryPath: entryPath)
        return ImageDecode.fromData(data)
    }

    // MARK: - Prefetch
    func prefetch(around index: Int, radius: Int = 2) {
        guard !pages.isEmpty else { return }
        let start = max(0, index + 1)
        let end = min(pages.count - 1, index + radius)
        guard start <= end else { return }
        for i in start...end {
            let page = pages[i]
            let key = page.path
            if memoryCache.object(forKey: key as NSString) != nil { continue }
            Task.detached(priority: .utility) { [weak self] in
                guard let self = self else { return }
                let shouldStart = await self.prefetchTracker.shouldStart(key)
                guard shouldStart else { return }
                autoreleasepool {
                    _ = self.getPageImage(at: i)
                }
                await self.prefetchTracker.finish(key)
            }
        }
    }

    // 限制预取并发与去重
    private actor PrefetchTracker {
        private var inFlight: Set<String> = []
        func shouldStart(_ key: String) -> Bool {
            if inFlight.contains(key) { return false }
            inFlight.insert(key)
            return true
        }
        func finish(_ key: String) {
            inFlight.remove(key)
        }
    }
}

enum MangaPageLoaderError: LocalizedError {
    case seriesNotSupported
    
    var errorDescription: String? {
        switch self {
        case .seriesNotSupported:
            return "系列文件夹不支持直接阅读，请选择具体的漫画"
        }
    }
}
