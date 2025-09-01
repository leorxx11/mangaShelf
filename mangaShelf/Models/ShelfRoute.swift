//
//  ShelfRoute.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/29.
//

import Foundation

// 用于 MangaShelfView 的导航路径类型，便于在不同视图间共享与持久化
enum ShelfRoute: Hashable {
    case subShelf(Manga)
    case read(Manga)
}

