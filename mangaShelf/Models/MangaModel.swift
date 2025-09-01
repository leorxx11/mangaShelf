//
//  MangaModel.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation
import SwiftUI

enum MangaType {
    case folder
    case zip
    case image   // 单张图片作为一个条目
    case series  // 系列文件夹，包含多个漫画
}

struct Manga: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let type: MangaType
    let path: URL
    let coverImagePath: URL?
    let rootURL: URL? // 保存根目录URL用于安全作用域访问
    let subMangas: [Manga]? // 子漫画，用于系列文件夹
    
    init(title: String, type: MangaType, path: URL, coverImagePath: URL? = nil, rootURL: URL? = nil, subMangas: [Manga]? = nil) {
        self.title = title
        self.type = type
        self.path = path
        self.coverImagePath = coverImagePath
        self.rootURL = rootURL
        self.subMangas = subMangas
    }
    
    var isSeries: Bool {
        return type == .series && subMangas != nil
    }
}

class MangaStore: ObservableObject {
    @Published var mangas: [Manga] = []
    
    init() {
        // 启动时从缓存加载已导入的漫画
        mangas = MangaCache.shared.loadMangas()
    }
    
    func addManga(_ manga: Manga) {
        mangas.append(manga)
        MangaCache.shared.saveMangas(mangas)
    }
    
    func deleteManga(_ manga: Manga) {
        mangas.removeAll { $0.id == manga.id }
        MangaCache.shared.saveMangas(mangas)
    }
    
    func clearMangas() {
        mangas.removeAll()
        // 同时清除图片缓存
        ImageCacheManager.shared.clearCache()
        // 清空持久化的导入列表
        MangaCache.shared.clearCache()
    }
    
    func setMangas(_ newMangas: [Manga]) {
        mangas = newMangas
        MangaCache.shared.saveMangas(newMangas)
    }
}
