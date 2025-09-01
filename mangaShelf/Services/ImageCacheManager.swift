//
//  ImageCacheManager.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let coverCacheDirectory: URL
    private let pagesCacheRootDirectory: URL
    private let thumbCacheDirectory: URL
    
    private init() {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        coverCacheDirectory = cachesDir.appendingPathComponent("MangaCovers")
        pagesCacheRootDirectory = cachesDir.appendingPathComponent("MangaPages")
        thumbCacheDirectory = cachesDir.appendingPathComponent("MangaThumbs")

        // 创建缓存目录
        try? FileManager.default.createDirectory(at: coverCacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: pagesCacheRootDirectory, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbCacheDirectory, withIntermediateDirectories: true)
        // 初始化缓存目录
    }
    
    func getCachedImagePath(for zipURL: URL) -> URL {
        let base = zipURL.deletingPathExtension().lastPathComponent
        var suffix = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: zipURL.path) {
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let mtime = Int(((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0))
            suffix = "sz\(size)_t\(mtime)"
        }
        let filename = "\(base)_\(suffix)_cover_v2.jpg"
        return coverCacheDirectory.appendingPathComponent(filename)
    }
    
    func cacheImage(data: Data, for zipURL: URL) -> URL? {
        let cachePath = getCachedImagePath(for: zipURL)

        do {
            try data.write(to: cachePath)
            return cachePath
        } catch {
            return nil
        }
    }
    
    func getCachedImage(for zipURL: URL) -> URL? {
        let cachePath = getCachedImagePath(for: zipURL)
        return FileManager.default.fileExists(atPath: cachePath.path) ? cachePath : nil
    }

    // MARK: - 页图片缓存（按 ZIP + entryPath）
    private func pageCacheFolder(for zipURL: URL) -> URL {
        // 以 zip 基名 + (文件大小 + 修改时间) 作为子目录，确保文件变更时缓存失效
        let base = zipURL.deletingPathExtension().lastPathComponent
        var suffix = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: zipURL.path) {
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let mtime = Int(((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0))
            suffix = "sz\(size)_t\(mtime)"
        }
        let folderName = sanitizedFilename(from: "\(base)_\(suffix)")
        return pagesCacheRootDirectory.appendingPathComponent(folderName)
    }

    private func sanitizedFilename(from entryPath: String) -> String {
        // 将 ZIP 内路径转为安全文件名
        var name = entryPath.replacingOccurrences(of: "/", with: "_")
        name = name.replacingOccurrences(of: ":", with: "_")
        name = name.replacingOccurrences(of: "\\", with: "_")
        return name
    }

    func getCachedPage(for zipURL: URL, entryPath: String) -> URL? {
        let folder = pageCacheFolder(for: zipURL)
        let filename = sanitizedFilename(from: entryPath)
        let cachePath = folder.appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: cachePath.path) {
            return cachePath
        }
        return nil
    }

    func cachePageImage(data: Data, for zipURL: URL, entryPath: String) -> URL? {
        let folder = pageCacheFolder(for: zipURL)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            
        }

        let filename = sanitizedFilename(from: entryPath)
        let cachePath = folder.appendingPathComponent(filename)
        do {
            try data.write(to: cachePath)
            return cachePath
        } catch {
            return nil
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: coverCacheDirectory)
        try? FileManager.default.createDirectory(at: coverCacheDirectory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: pagesCacheRootDirectory)
        try? FileManager.default.createDirectory(at: pagesCacheRootDirectory, withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: thumbCacheDirectory)
        try? FileManager.default.createDirectory(at: thumbCacheDirectory, withIntermediateDirectories: true)
        
    }
}

// MARK: - Generic thumbnail cache (for loose images)
extension ImageCacheManager {
    private func thumbFilename(for fileURL: URL, maxPixel: Int) -> String {
        var suffix = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path) {
            let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
            let mtime = Int(((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0))
            suffix = "sz\(size)_t\(mtime)"
        }
        let base = fileURL.deletingPathExtension().lastPathComponent
        return "\(base)_\(suffix)_p\(maxPixel).jpg"
    }

    func getCachedThumbnail(for fileURL: URL, maxPixel: Int) -> URL? {
        let filename = thumbFilename(for: fileURL, maxPixel: maxPixel)
        let path = thumbCacheDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: path.path) ? path : nil
    }

    func cacheThumbnail(_ data: Data, for fileURL: URL, maxPixel: Int) -> URL? {
        let filename = thumbFilename(for: fileURL, maxPixel: maxPixel)
        let path = thumbCacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: path)
            return path
        } catch {
            return nil
        }
    }
}
