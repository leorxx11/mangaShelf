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
    
    private let manga: Manga
    
    init(manga: Manga) {
        self.manga = manga
        print("📖 🏗️ 创建MangaPageLoader - 漫画: \(manga.title)")
        print("📖 漫画类型: \(manga.type)")
        print("📖 漫画路径: \(manga.path.path)")
        print("📖 根目录: \(manga.rootURL?.path ?? "nil")")
    }
    
    func loadPages() {
        print("📖 开始加载漫画页面: \(manga.title)")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let loadedPages = try await loadPagesAsync()
                await MainActor.run {
                    self.pages = loadedPages
                    self.isLoading = false
                    print("📖 ✅ 成功加载 \(loadedPages.count) 页")
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("📖 ❌ 加载页面失败: \(error)")
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
        case .series:
            throw MangaPageLoaderError.seriesNotSupported
        }
    }
    
    private func loadPagesFromFolder() throws -> [MangaPage] {
        print("📖 从文件夹加载页面: \(manga.path.path)")
        
        // 如果rootURL为nil，尝试从文件夹路径推断根目录
        var effectiveRootURL = manga.rootURL
        if effectiveRootURL == nil {
            if manga.path.path.contains("/Documents/comic/") {
                let comicPath = "/Users/leo/Documents/comic"
                effectiveRootURL = URL(fileURLWithPath: comicPath)
                print("📖 推断根目录: \(comicPath)")
            }
        }
        
        let hasAccess = effectiveRootURL?.startAccessingSecurityScopedResource() == true
        if hasAccess {
            print("📖 文件夹安全作用域访问已启用")
        } else {
            print("📖 ❌ 文件夹未启用安全作用域访问")
        }
        
        defer {
            if hasAccess {
                effectiveRootURL?.stopAccessingSecurityScopedResource()
                print("📖 文件夹安全作用域访问已停止")
            }
        }
        
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: manga.path, includingPropertiesForKeys: [.nameKey])
        
        let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
        let imageFiles = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return imageExtensions.contains(ext)
        }.sorted { url1, url2 in
            return url1.lastPathComponent.localizedStandardCompare(url2.lastPathComponent) == .orderedAscending
        }
        
        print("📖 文件夹中找到 \(imageFiles.count) 个图片文件")
        
        return imageFiles.enumerated().map { index, url in
            MangaPage(index: index, path: url.lastPathComponent, url: url)
        }
    }
    
    private func loadPagesFromZip() throws -> [MangaPage] {
        print("📖 从ZIP文件加载页面: \(manga.path.path)")
        print("📖 manga.rootURL: \(manga.rootURL?.path ?? "nil")")
        
        // 如果rootURL为nil，尝试从ZIP路径推断根目录
        var effectiveRootURL = manga.rootURL
        if effectiveRootURL == nil {
            if manga.path.path.contains("/Documents/comic/") {
                let comicPath = "/Users/leo/Documents/comic"
                effectiveRootURL = URL(fileURLWithPath: comicPath)
                print("📖 推断根目录: \(comicPath)")
            }
        }
        
        let hasAccess = effectiveRootURL?.startAccessingSecurityScopedResource() == true
        if hasAccess {
            print("📖 安全作用域访问已启用")
        } else {
            print("📖 ❌ 未启用安全作用域访问，effectiveRootURL是否为nil: \(effectiveRootURL == nil)")
        }
        
        defer {
            if hasAccess {
                effectiveRootURL?.stopAccessingSecurityScopedResource()
                print("📖 安全作用域访问已停止")
            }
        }
        
        let images = ZipManager.getAllImagesFromZip(at: manga.path)
        print("📖 ZIP中找到 \(images.count) 个图片文件")
        
        return images.enumerated().map { index, image in
            MangaPage(index: index, path: image.path, data: image.data)
        }
    }
    
    func getPageImage(at index: Int) -> NSImage? {
        guard index >= 0 && index < pages.count else {
            print("📖 ❌ 页面索引超出范围: \(index)/\(pages.count)")
            return nil
        }
        
        let page = pages[index]
        print("📖 获取第 \(index + 1) 页图片: \(page.path)")
        
        if let data = page.data {
            print("📖 使用内存数据加载图片，大小: \(data.count) 字节")
            let image = NSImage(data: data)
            if image != nil {
                print("📖 ✅ 成功从数据创建图片")
            } else {
                print("📖 ❌ 无法从数据创建图片")
            }
            return image
        } else if let url = page.url {
            print("📖 从文件加载图片: \(url.path)")
            return loadImageFromFile(url: url)
        }
        
        print("📖 ❌ 页面既没有数据也没有URL")
        return nil
    }
    
    private func loadImageFromFile(url: URL) -> NSImage? {
        // 如果rootURL为nil，尝试从文件路径推断根目录
        var effectiveRootURL = manga.rootURL
        if effectiveRootURL == nil {
            if url.path.contains("/Documents/comic/") {
                let comicPath = "/Users/leo/Documents/comic"
                effectiveRootURL = URL(fileURLWithPath: comicPath)
            }
        }
        
        let hasAccess = effectiveRootURL?.startAccessingSecurityScopedResource() == true
        defer {
            if hasAccess {
                effectiveRootURL?.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            return NSImage(data: data)
        } catch {
            print("📖 ❌ 读取图片文件失败: \(error)")
            return nil
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