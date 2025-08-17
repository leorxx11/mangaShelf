//
//  ReadingProgress.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

struct ReadingProgress: Codable, Identifiable {
    let id = UUID()
    let mangaPath: String
    var currentPage: Int
    var totalPages: Int
    var lastReadDate: Date
    var isCompleted: Bool {
        return currentPage >= totalPages - 1
    }
    var progressPercentage: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage + 1) / Double(totalPages) * 100
    }
    
    init(mangaPath: String, currentPage: Int = 0, totalPages: Int) {
        self.mangaPath = mangaPath
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastReadDate = Date()
    }
    
    mutating func updateProgress(currentPage: Int) {
        self.currentPage = currentPage
        self.lastReadDate = Date()
    }
}

class ReadingProgressManager: ObservableObject {
    static let shared = ReadingProgressManager()
    
    @Published private var progressMap: [String: ReadingProgress] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let progressKey = "ReadingProgress"
    
    private init() {
        // 不再从缓存加载进度
    }
    
    func getProgress(for manga: Manga) -> ReadingProgress? {
        return progressMap[manga.path.path]
    }
    
    func updateProgress(for manga: Manga, currentPage: Int, totalPages: Int) {
        let path = manga.path.path
        
        if var progress = progressMap[path] {
            progress.updateProgress(currentPage: currentPage)
            progress.totalPages = totalPages
            progressMap[path] = progress
        } else {
            let newProgress = ReadingProgress(
                mangaPath: path,
                currentPage: currentPage,
                totalPages: totalPages
            )
            progressMap[path] = newProgress
        }
        
        // 不再保存到持久化存储
        print("📚 更新阅读进度: \(manga.title) - \(currentPage + 1)/\(totalPages)")
    }
    
    func deleteProgress(for manga: Manga) {
        progressMap.removeValue(forKey: manga.path.path)
        print("📚 删除阅读进度: \(manga.title)")
    }
    
    func getAllProgress() -> [ReadingProgress] {
        return Array(progressMap.values).sorted { $0.lastReadDate > $1.lastReadDate }
    }
    
    func getRecentlyRead(limit: Int = 10) -> [ReadingProgress] {
        return getAllProgress().prefix(limit).map { $0 }
    }
    
    func clearAllProgress() {
        progressMap.removeAll()
        print("📚 清除所有阅读进度")
    }
}