//
//  ImageCacheManager.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

class ImageCacheManager {
    static let shared = ImageCacheManager()
    private let cacheDirectory: URL
    
    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("MangaCovers")
        
        // 创建缓存目录
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗂️ 缓存目录: \(cacheDirectory.path)")
    }
    
    func getCachedImagePath(for zipURL: URL) -> URL {
        let filename = zipURL.lastPathComponent.replacingOccurrences(of: ".zip", with: "_cover.jpg")
        return cacheDirectory.appendingPathComponent(filename)
    }
    
    func cacheImage(data: Data, for zipURL: URL) -> URL? {
        let cachePath = getCachedImagePath(for: zipURL)
        
        do {
            try data.write(to: cachePath)
            print("🗂️ ✅ 缓存图片成功: \(cachePath.lastPathComponent)")
            return cachePath
        } catch {
            print("🗂️ ❌ 缓存图片失败: \(error)")
            return nil
        }
    }
    
    func getCachedImage(for zipURL: URL) -> URL? {
        let cachePath = getCachedImagePath(for: zipURL)
        
        if FileManager.default.fileExists(atPath: cachePath.path) {
            print("🗂️ ✅ 找到缓存图片: \(cachePath.lastPathComponent)")
            return cachePath
        } else {
            print("🗂️ 📭 缓存图片不存在: \(cachePath.lastPathComponent)")
            return nil
        }
    }
    
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        print("🗂️ 🧹 清空缓存完成")
    }
}