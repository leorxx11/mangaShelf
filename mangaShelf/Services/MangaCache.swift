//
//  MangaCache.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

class MangaCache {
    static let shared = MangaCache()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "CachedMangas"
    
    private init() {}
    
    func saveMangas(_ mangas: [Manga]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(mangas.map { MangaCacheItem(from: $0) })
            userDefaults.set(data, forKey: cacheKey)
            print("💾 成功缓存 \(mangas.count) 个漫画")
        } catch {
            print("💾 ❌ 缓存漫画失败: \(error)")
        }
    }
    
    func loadMangas() -> [Manga] {
        guard let data = userDefaults.data(forKey: cacheKey) else {
            print("💾 没有找到缓存的漫画")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let cacheItems = try decoder.decode([MangaCacheItem].self, from: data)
            let mangas = cacheItems.compactMap { $0.toManga() }
            print("💾 成功加载 \(mangas.count) 个缓存漫画")
            return mangas
        } catch {
            print("💾 ❌ 加载缓存漫画失败: \(error)")
            return []
        }
    }
    
    func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
        print("💾 已清除漫画缓存")
    }
}

// MARK: - Cache Item
struct MangaCacheItem: Codable {
    let title: String
    let type: MangaTypeCache
    let pathString: String
    let coverImagePathString: String?
    let rootURLString: String?
    // 安全作用域书签，用于跨重启访问外部目录
    let rootBookmarkData: Data?
    let subMangas: [MangaCacheItem]?
    
    init(from manga: Manga) {
        self.title = manga.title
        self.type = MangaTypeCache(from: manga.type)
        self.pathString = manga.path.path
        self.coverImagePathString = manga.coverImagePath?.path
        self.rootURLString = manga.rootURL?.path
        // 为根目录创建安全作用域书签（若可用）
        if let root = manga.rootURL {
            self.rootBookmarkData = try? root.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        } else {
            self.rootBookmarkData = nil
        }
        self.subMangas = manga.subMangas?.map { MangaCacheItem(from: $0) }
    }
    
    func toManga() -> Manga? {
        let mangaType = type.toMangaType()
        let path = URL(fileURLWithPath: pathString)
        let coverImagePath = coverImagePathString.map { URL(fileURLWithPath: $0) }
        // 优先从书签恢复安全作用域 URL，其次回退到字符串路径
        var rootURL: URL? = nil
        if let bookmark = rootBookmarkData {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                rootURL = resolved
            }
        }
        if rootURL == nil {
            rootURL = rootURLString.map { URL(fileURLWithPath: $0) }
        }
        let subMangasArray = subMangas?.compactMap { $0.toManga() }
        
        return Manga(
            title: title,
            type: mangaType,
            path: path,
            coverImagePath: coverImagePath,
            rootURL: rootURL,
            subMangas: subMangasArray
        )
    }
}

enum MangaTypeCache: String, Codable {
    case folder = "folder"
    case zip = "zip"
    case series = "series"
    
    init(from mangaType: MangaType) {
        switch mangaType {
        case .folder:
            self = .folder
        case .zip:
            self = .zip
        case .series:
            self = .series
        }
    }
    
    func toMangaType() -> MangaType {
        switch self {
        case .folder:
            return .folder
        case .zip:
            return .zip
        case .series:
            return .series
        }
    }
}
