//
//  MangaScanner.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

class MangaScanner {
    static func scanDirectory(at url: URL) -> [Manga] {
        print("🔍 开始扫描目录: \(url.path)")
        var mangas: [Manga] = []
        let fileManager = FileManager.default
        
        // 首先尝试直接读取目录内容
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey])
            print("🔍 直接读取目录成功，找到 \(contents.count) 个项目:")
            for item in contents {
                print("🔍 - \(item.lastPathComponent)")
            }
        } catch {
            print("🔍 直接读取目录失败: \(error)")
        }
        
        // 使用简化的方法直接处理目录内容
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey])
            print("🔍 开始处理 \(contents.count) 个项目")
            
            for itemURL in contents {
                print("🔍 检查项目: \(itemURL.lastPathComponent)")
                print("🔍 完整路径: \(itemURL.path)")
                print("🔍 是否为目录: \(itemURL.hasDirectoryPath)")
                
                if isSeriesFolder(itemURL) {
                    print("🔍 ✅ 发现系列文件夹: \(itemURL.lastPathComponent)")
                    if let seriesManga = createSeriesManga(from: itemURL, rootURL: url) {
                        mangas.append(seriesManga)
                        print("🔍 ✅ 成功添加系列: \(seriesManga.title) (包含 \(seriesManga.subMangas?.count ?? 0) 个漫画)")
                    }
                } else if isFolderManga(itemURL) {
                    print("🔍 ✅ 发现文件夹漫画: \(itemURL.lastPathComponent)")
                    if let manga = createFolderManga(from: itemURL, rootURL: url) {
                        mangas.append(manga)
                        print("🔍 ✅ 成功添加文件夹漫画: \(manga.title)")
                    }
                } else if isZipManga(itemURL) {
                    print("🔍 ✅ 发现ZIP漫画: \(itemURL.lastPathComponent)")
                    if let manga = createZipManga(from: itemURL, rootURL: url) {
                        mangas.append(manga)
                        print("🔍 ✅ 成功添加ZIP漫画: \(manga.title)")
                    }
                } else {
                    print("🔍 ❌ 跳过项目: \(itemURL.lastPathComponent) (不是漫画)")
                }
            }
        } catch {
            print("🔍 读取目录内容失败: \(error)")
        }
        
        print("🔍 扫描完成，共找到 \(mangas.count) 个漫画")
        
        // 按标题字母顺序排序
        let sortedMangas = mangas.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        print("🔍 漫画已按字母顺序排序")
        
        return sortedMangas
    }
    
    private static func isFolderManga(_ url: URL) -> Bool {
        guard url.hasDirectoryPath else { return false }
        
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            
            let imageFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "webp"].contains(ext)
            }
            
            let hasCoverImage = contents.contains { url in
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                let ext = url.pathExtension.lowercased()
                return name == "cover" && ["jpg", "jpeg", "png", "webp"].contains(ext)
            }
            
            return imageFiles.count > 0 && hasCoverImage
        } catch {
            return false
        }
    }
    
    private static func isSeriesFolder(_ url: URL) -> Bool {
        guard url.hasDirectoryPath else { 
            print("🔍 系列检查: \(url.lastPathComponent) - 不是目录")
            return false 
        }
        
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            print("🔍 系列检查: \(url.lastPathComponent) - 包含 \(contents.count) 个项目")
            
            // 检查是否包含多个子文件夹或ZIP文件
            let subItems = contents.filter { subURL in
                let isFolder = subURL.hasDirectoryPath
                let isZip = subURL.pathExtension.lowercased() == "zip"
                if isFolder || isZip {
                    print("🔍 - 子项目: \(subURL.lastPathComponent) (文件夹: \(isFolder), ZIP: \(isZip))")
                }
                return isFolder || isZip
            }
            
            // 检查是否有非封面的直接图片文件
            let nonCoverImages = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                return ["jpg", "jpeg", "png", "webp"].contains(ext) && name != "cover"
            }
            
            print("🔍 系列检查: \(url.lastPathComponent) - 子项目: \(subItems.count), 非封面图片: \(nonCoverImages.count)")
            
            // 如果包含2个或以上的子项目，并且没有非封面的直接图片，认为是系列文件夹
            let isSeries = subItems.count >= 2 && nonCoverImages.isEmpty
            print("🔍 系列检查结果: \(url.lastPathComponent) - 是系列: \(isSeries)")
            
            return isSeries
        } catch {
            print("🔍 系列检查失败: \(url.lastPathComponent) - \(error)")
            return false
        }
    }
    
    private static func isZipManga(_ url: URL) -> Bool {
        let isZip = url.pathExtension.lowercased() == "zip"
        print("🔍 检查ZIP: \(url.lastPathComponent), 扩展名: '\(url.pathExtension)', 是ZIP: \(isZip)")
        return isZip
    }
    
    private static func createFolderManga(from url: URL, rootURL: URL) -> Manga? {
        let title = url.lastPathComponent
        let coverPath = findCoverImage(in: url, rootURL: rootURL)
        
        return Manga(
            title: title,
            type: .folder,
            path: url,
            coverImagePath: coverPath,
            rootURL: rootURL
        )
    }
    
    private static func createSeriesManga(from url: URL, rootURL: URL) -> Manga? {
        let title = url.lastPathComponent
        print("📚 创建系列漫画: \(title)")
        let fileManager = FileManager.default
        
        var subMangas: [Manga] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            print("📚 系列 \(title) 包含 \(contents.count) 个项目")
            
            for subURL in contents {
                print("📚 检查子项目: \(subURL.lastPathComponent)")
                if isFolderManga(subURL) {
                    print("📚 - 发现文件夹漫画: \(subURL.lastPathComponent)")
                    if let manga = createFolderManga(from: subURL, rootURL: rootURL) {
                        subMangas.append(manga)
                        print("📚 - ✅ 成功添加文件夹漫画: \(manga.title)")
                    }
                } else if isZipManga(subURL) {
                    print("📚 - 发现ZIP漫画: \(subURL.lastPathComponent)")
                    if let manga = createZipManga(from: subURL, rootURL: rootURL) {
                        subMangas.append(manga)
                        print("📚 - ✅ 成功添加ZIP漫画: \(manga.title)")
                    }
                } else {
                    print("📚 - 跳过非漫画项目: \(subURL.lastPathComponent)")
                }
            }
        } catch {
            print("📚 ❌ 读取系列文件夹内容失败: \(error)")
            return nil
        }
        
        // 对子漫画按标题字母顺序排序
        let sortedSubMangas = subMangas.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        print("📚 系列 \(title) 最终包含 \(sortedSubMangas.count) 个漫画，已按字母顺序排序")
        
        // 查找系列文件夹中的封面图片
        let coverPath = findCoverImage(in: url, rootURL: rootURL)
        print("📚 系列封面路径: \(coverPath?.path ?? "无")")
        
        let seriesManga = Manga(
            title: title,
            type: .series,
            path: url,
            coverImagePath: coverPath,
            rootURL: rootURL,
            subMangas: sortedSubMangas
        )
        
        print("📚 ✅ 成功创建系列漫画: \(seriesManga.title), isSeries: \(seriesManga.isSeries)")
        return seriesManga
    }
    
    private static func createZipManga(from url: URL, rootURL: URL) -> Manga? {
        let title = url.deletingPathExtension().lastPathComponent
        let coverPath = extractZipCover(from: url, rootURL: rootURL)
        
        return Manga(
            title: title,
            type: .zip,
            path: url,
            coverImagePath: coverPath,
            rootURL: rootURL
        )
    }
    
    private static func extractZipCover(from zipURL: URL, rootURL: URL) -> URL? {
        print("🗜️ 开始为ZIP提取封面: \(zipURL.lastPathComponent)")
        
        // 先检查缓存
        if let cachedCover = ImageCacheManager.shared.getCachedImage(for: zipURL) {
            return cachedCover
        }
        
        // 启用安全作用域访问
        let hasAccess = rootURL.startAccessingSecurityScopedResource()
        if hasAccess {
            print("🗜️ 安全作用域访问已启用")
        } else {
            print("🗜️ ❌ 未启用安全作用域访问")
        }
        
        defer {
            if hasAccess {
                rootURL.stopAccessingSecurityScopedResource()
                print("🗜️ 安全作用域访问已停止")
            }
        }
        
        // 从ZIP提取封面
        guard let imageData = ZipManager.getFirstImageFromZip(at: zipURL) else {
            print("🗜️ ❌ 无法从ZIP提取封面")
            return nil
        }
        
        // 缓存图片
        return ImageCacheManager.shared.cacheImage(data: imageData, for: zipURL)
    }
    
    private static func findCoverImage(in folderURL: URL, rootURL: URL) -> URL? {
        print("🔍 查找封面图片在: \(folderURL.path)")
        let fileManager = FileManager.default
        
        // 启用安全作用域访问
        let hasAccess = rootURL.startAccessingSecurityScopedResource()
        if hasAccess {
            print("🔍 安全作用域访问已启用")
        } else {
            print("🔍 ❌ 未启用安全作用域访问")
        }
        
        defer {
            if hasAccess {
                rootURL.stopAccessingSecurityScopedResource()
                print("🔍 安全作用域访问已停止")
            }
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            print("🔍 文件夹内容 (\(contents.count) 个文件):")
            for item in contents {
                print("🔍 - \(item.lastPathComponent)")
            }
            
            let coverImage = contents.first { url in
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                let ext = url.pathExtension.lowercased()
                let isCover = name == "cover" && ["jpg", "jpeg", "png", "webp"].contains(ext)
                print("🔍 检查封面: \(url.lastPathComponent), 名称: '\(name)', 扩展名: '\(ext)', 是封面: \(isCover)")
                return isCover
            }
            
            if let cover = coverImage {
                print("🔍 ✅ 找到封面: \(cover.path)")
            } else {
                print("🔍 ❌ 未找到封面图片")
            }
            
            return coverImage
        } catch {
            print("🔍 ❌ 读取文件夹内容失败: \(error)")
            return nil
        }
    }
}