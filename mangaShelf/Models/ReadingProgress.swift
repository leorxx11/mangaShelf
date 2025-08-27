//
//  ReadingProgress.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation

struct ReadingProgress: Codable, Identifiable {
    let id: UUID
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
        self.id = UUID()
        self.mangaPath = mangaPath
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.lastReadDate = Date()
    }

    // 自定义编解码：不从存储中解码 id，运行时生成
    private enum CodingKeys: String, CodingKey {
        case mangaPath, currentPage, totalPages, lastReadDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.mangaPath = try container.decode(String.self, forKey: .mangaPath)
        self.currentPage = try container.decode(Int.self, forKey: .currentPage)
        self.totalPages = try container.decode(Int.self, forKey: .totalPages)
        self.lastReadDate = try container.decode(Date.self, forKey: .lastReadDate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mangaPath, forKey: .mangaPath)
        try container.encode(currentPage, forKey: .currentPage)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(lastReadDate, forKey: .lastReadDate)
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
        loadFromDisk()
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
        
        saveToDisk()
        print("📚 更新阅读进度: \(manga.title) - \(currentPage + 1)/\(totalPages)")
    }
    
    func deleteProgress(for manga: Manga) {
        progressMap.removeValue(forKey: manga.path.path)
        saveToDisk()
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
        saveToDisk()
        print("📚 清除所有阅读进度")
    }

    // MARK: - Persistence
    private func loadFromDisk() {
        guard let data = userDefaults.data(forKey: progressKey) else { return }
        let strategies: [JSONDecoder.DateDecodingStrategy] = [
            .iso8601,
            .deferredToDate,
            .secondsSince1970,
            .millisecondsSince1970
        ]
        var loaded: [ReadingProgress]? = nil
        var lastError: Error? = nil
        for strat in strategies {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = strat
                let list = try decoder.decode([ReadingProgress].self, from: data)
                loaded = list
                print("📚 从本地加载阅读进度(策略: \(strat)): \(list.count) 条")
                break
            } catch {
                lastError = error
            }
        }
        if let list = loaded {
            var map: [String: ReadingProgress] = [:]
            for item in list {
                map[item.mangaPath] = item
            }
            progressMap = map
        } else if let err = lastError {
            print("📚 ❌ 读取阅读进度失败: \(err)")
        }
    }

    private func saveToDisk() {
        let list = Array(progressMap.values)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(list)
            userDefaults.set(data, forKey: progressKey)
        } catch {
            print("📚 ❌ 保存阅读进度失败: \(error)")
        }
    }
}
