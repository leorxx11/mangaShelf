//
//  MangaScanner.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

class MangaScanner {
    static func scanDirectory(at url: URL) -> [Manga] {
        
        var mangas: [Manga] = []
        let fileManager = FileManager.default
        
        // 首先尝试直接读取目录内容
        do {
            let _ = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey])
        } catch {
            print("读取目录失败: \(error)")
        }
        
        // 使用简化的方法直接处理目录内容
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey])
            
            
            for itemURL in contents {
                
                
                if isSeriesFolder(itemURL) {
                    
                    if let seriesManga = createSeriesManga(from: itemURL, rootURL: url) {
                        mangas.append(seriesManga)
                        
                    }
                } else if isFolderManga(itemURL) {
                    
                    if let manga = createFolderManga(from: itemURL, rootURL: url) {
                        mangas.append(manga)
                        
                    }
                } else if isZipManga(itemURL) {
                    if let manga = createZipManga(from: itemURL, rootURL: url) {
                        mangas.append(manga)
                    }
                } else {
                    // 非漫画项，忽略
                }
            }
        } catch {
            print("读取目录内容失败: \(error)")
        }
        
        
        
        // 按标题字母顺序排序
        let sortedMangas = mangas.sorted(by: MangaScanner.mangaTitleNaturalLessThan(_:_:))
        
        
        return sortedMangas
    }
    
    private static func isFolderManga(_ url: URL) -> Bool {
        // 仅当“该目录内有图片”且“没有任何 zip/cbz 子项”时，才视为单本的文件夹漫画。
        // 这样可避免把包含若干 zip 的系列误判为单本。
        guard url.hasDirectoryPath else { return false }

        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            let hasZip = contents.contains { u in
                let ext = u.pathExtension.lowercased(); return ext == "zip" || ext == "cbz"
            }
            if hasZip { return false }

            // 子目录若含图片，则倾向于将上层视为系列而非单本
            let imageExt = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
            let hasImagesHere = contents.contains { u in imageExt.contains(u.pathExtension.lowercased()) }
            if !hasImagesHere { return false }

            // 若存在包含图片的子文件夹，也不将当前目录视为单本
            for sub in contents where sub.hasDirectoryPath {
                if let subContents = try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil),
                   subContents.contains(where: { imageExt.contains($0.pathExtension.lowercased()) }) {
                    return false
                }
            }

            return true
        } catch {
            return false
        }
    }
    
    private static func isSeriesFolder(_ url: URL) -> Bool {
        // 系列判断：只要顶层包含 zip/cbz，或包含“含图片的子文件夹”，或根层存在图片，即认为是系列
        guard url.hasDirectoryPath else { return false }
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            let zipCount = contents.filter { ["zip", "cbz"].contains($0.pathExtension.lowercased()) }.count
            var folderMangaCount = 0
            for sub in contents where sub.hasDirectoryPath {
                if isFolderManga(sub) { folderMangaCount += 1 }
            }
            // 根层是否有图片（忽略 cover）
            let imageExt = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
            let hasRootImages = contents.contains { u in
                let name = u.deletingPathExtension().lastPathComponent.lowercased()
                return imageExt.contains(u.pathExtension.lowercased()) && name != "cover"
            }
            return zipCount >= 1 || folderMangaCount >= 1 || hasRootImages
        } catch {
            print("系列检查失败: \(url.lastPathComponent) - \(error)")
            return false
        }
    }
    
    private static func isZipManga(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "zip" || ext == "cbz"
    }
    
    private static func createFolderManga(from url: URL, rootURL: URL, overrideTitle: String? = nil) -> Manga? {
        let title = overrideTitle ?? url.lastPathComponent
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
        
        let fileManager = FileManager.default
        
        var subMangas: [Manga] = []
        var topLevelZips: [URL] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
            
            
            for subURL in contents {
                
                if isFolderManga(subURL) {
                    
                    if let manga = createFolderManga(from: subURL, rootURL: rootURL) {
                        subMangas.append(manga)
                        
                    }
                } else if isZipManga(subURL) {
                    
                    if let manga = createZipManga(from: subURL, rootURL: rootURL) {
                        subMangas.append(manga)
                        
                    }
                    topLevelZips.append(subURL)
                } else {
                    // 根层的单张图片：加入为独立条目（排除 cover.*）
                    let name = subURL.deletingPathExtension().lastPathComponent.lowercased()
                    let ext = subURL.pathExtension.lowercased()
                    let imageExt = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
                    if imageExt.contains(ext) && name != "cover" {
                        let m = Manga(
                            title: subURL.deletingPathExtension().lastPathComponent,
                            type: .image,
                            path: subURL,
                            coverImagePath: subURL,
                            rootURL: rootURL,
                            subMangas: nil
                        )
                        subMangas.append(m)
                    }
                }
            }
        } catch {
            print("读取系列文件夹内容失败: \(error)")
            return nil
        }
        // 对子漫画按标题的自然顺序排序（数字感知，如 1-8, 9-10, 11-12）
        let sortedSubMangas = subMangas.sorted(by: MangaScanner.mangaTitleNaturalLessThan(_:_:))

        // 1) 递归查找系列目录下的 cover.*（只匹配 cover，不回退第一张）
        var coverPath: URL? = findCoverImageRecursively(in: url, rootURL: rootURL)
        
        // 2) 若没有 cover，则在顶层 ZIP 中按自然顺序选择：优先 cover.*，否则第一张；若 ZIP 损坏则继续向后扫描
        if coverPath == nil {
            let sortedZips = topLevelZips.sorted { a, b in
                a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            for zip in sortedZips {
                if let data = ZipManager.getPreferredCoverOrFirstImageData(from: zip) {
                    if let cached = ImageCacheManager.shared.cacheImage(data: data, for: zip) {
                        coverPath = cached
                        break
                    }
                } else {
                    // 损坏或无图片，继续下一个 zip
                    continue
                }
            }
        }
        
        
        let seriesManga = Manga(
            title: title,
            type: .series,
            path: url,
            coverImagePath: coverPath,
            rootURL: rootURL,
            subMangas: sortedSubMangas
        )
        
        
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
        
        
        // 先检查缓存
        if let cachedCover = ImageCacheManager.shared.getCachedImage(for: zipURL) {
            return cachedCover
        }
        
        // 启用安全作用域访问
        let hasAccess = rootURL.startAccessingSecurityScopedResource()
        
        
        defer {
            if hasAccess { rootURL.stopAccessingSecurityScopedResource() }
        }
        
        // 从ZIP提取封面：优先 cover.*，否则第一张
        guard let imageData = ZipManager.getPreferredCoverOrFirstImageData(from: zipURL) else { return nil }
        
        // 缓存图片
        return ImageCacheManager.shared.cacheImage(data: imageData, for: zipURL)
    }
    
    private static func findCoverImage(in folderURL: URL, rootURL: URL) -> URL? {
        
        let fileManager = FileManager.default
        
        // 启用安全作用域访问
        let hasAccess = rootURL.startAccessingSecurityScopedResource()
        
        
        defer {
            if hasAccess { rootURL.stopAccessingSecurityScopedResource() }
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            
            // 1) 优先 cover.*
            if let coverImage = contents.first(where: { url in
                let name = url.deletingPathExtension().lastPathComponent.lowercased()
                let ext = url.pathExtension.lowercased()
                return name == "cover" && ["jpg", "jpeg", "png", "webp"].contains(ext)
            }) {
                return coverImage
            }
            
            // 2) 回退：取文件夹内自然排序后的第一张图片
            let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
            let imageFiles = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                return imageExtensions.contains(ext)
            }.sorted { a, b in
                a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            }
            return imageFiles.first
        } catch {
            print("读取文件夹内容失败: \(error)")
            return nil
        }
    }

    // 已去除“单zip文件夹扁平化”兼容逻辑，保持文件夹作为系列识别

    /// 递归查找目录下的 cover.*（仅匹配 cover，不回退第一张）
    private static func findCoverImageRecursively(in folderURL: URL, rootURL: URL) -> URL? {
        let fm = FileManager.default
        let hasAccess = rootURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { rootURL.stopAccessingSecurityScopedResource() } }

        let allowedExt = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
        if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let item as URL in enumerator {
                let name = item.deletingPathExtension().lastPathComponent.lowercased()
                let ext = item.pathExtension.lowercased()
                if name == "cover" && allowedExt.contains(ext) {
                    return item
                }
            }
        }
        return nil
    }
}

// MARK: - Natural ordering by title (number-aware)
extension MangaScanner {
    /// 比较两个漫画标题的“自然顺序”（数字感知）。
    /// 规则：
    /// - 提取标题中的所有十进制整数序列，按序逐个比较（1 < 9 < 11）。
    /// - 若某一方没有数字，或数字序列完全相同，则回退到 `localizedStandardCompare`。
    static func mangaTitleNaturalLessThan(_ lhs: Manga, _ rhs: Manga) -> Bool {
        let lt = numericTokens(in: lhs.title)
        let rt = numericTokens(in: rhs.title)
        if !lt.isEmpty || !rt.isEmpty {
            let cmp = compareNumberLists(lt, rt)
            if cmp != .orderedSame { return cmp == .orderedAscending }
        }
        // 回退到 Finder 风格自然排序（包含数字感知）
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    private static func numericTokens(in text: String) -> [Int] {
        // 提取所有连续的 0-9 数字片段
        // 兼容常见格式："1-8话", "9-10", "第12卷" 等
        var tokens: [Int] = []
        let pattern = "\\d+"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let match = match, let r = Range(match.range, in: text) {
                    if let val = Int(text[r]) { tokens.append(val) }
                }
            }
        }
        return tokens
    }

    private static func compareNumberLists(_ a: [Int], _ b: [Int]) -> ComparisonResult {
        let n = min(a.count, b.count)
        for i in 0..<n {
            if a[i] < b[i] { return .orderedAscending }
            if a[i] > b[i] { return .orderedDescending }
        }
        // 前缀相同，短者在前
        if a.count < b.count { return .orderedAscending }
        if a.count > b.count { return .orderedDescending }
        return .orderedSame
    }
}
