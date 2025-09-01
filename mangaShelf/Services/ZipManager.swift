//
//  ZipManager.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation
import ZIPFoundation

class ZipManager {
    /// 在 ZIP 中优先寻找 cover.*，否则回退为第一张图片。返回图片 Data。
    static func getPreferredCoverOrFirstImageData(from url: URL) -> Data? {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]

            // 生成图片条目列表并自然排序
            let imageEntries: [(entry: Entry, path: String)] = archive.compactMap { entry in
                let ext = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                guard imageExtensions.contains(ext) else { return nil }
                return (entry, entry.path)
            }.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }

            guard !imageEntries.isEmpty else { return nil }

            // 先找 cover.*（忽略扩展名）
            if let cover = imageEntries.first(where: { URL(fileURLWithPath: $0.path).deletingPathExtension().lastPathComponent.lowercased() == "cover" }) {
                var data = Data()
                _ = try archive.extract(cover.entry) { chunk in data.append(chunk) }
                return data
            }

            // 回退第一张
            var data = Data()
            _ = try archive.extract(imageEntries[0].entry) { chunk in data.append(chunk) }
            return data
        } catch {
            print("ZIP优先封面提取失败: \(error)")
            return nil
        }
    }
    /// 列出 ZIP 中的图片条目路径（自然排序）
    static func listImageEntryPaths(in url: URL) -> [String] {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]

            let paths = archive.compactMap { entry -> String? in
                let pathExtension = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                return imageExtensions.contains(pathExtension) ? entry.path : nil
            }.sorted { lhs, rhs in
                lhs.localizedStandardCompare(rhs) == .orderedAscending
            }

            return paths
        } catch {
            print("枚举ZIP条目失败: \(error)")
            return []
        }
    }

    /// 从 ZIP 中按路径按需提取单个图片为 Data
    static func extractImageData(from url: URL, entryPath: String) -> Data? {
        do {
            let archive = try Archive(url: url, accessMode: .read)
            guard let entry = archive.first(where: { $0.path == entryPath }) else {
                print("未找到ZIP条目: \(entryPath)")
                return nil
            }

            var imageData = Data()
            _ = try archive.extract(entry) { data in
                imageData.append(data)
            }
            return imageData
        } catch {
            print("ZIP按需解压失败: \(error)")
            return nil
        }
    }

    static func getFirstImageFromZip(at url: URL) -> Data? {
        
        
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
            
            // 获取所有图片文件并按自然排序
            let imageEntries = archive.compactMap { entry -> (Entry, String)? in
                let pathExtension = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                if imageExtensions.contains(pathExtension) {
                    return (entry, entry.path)
                }
                return nil
            }.sorted { (tuple1: (Entry, String), tuple2: (Entry, String)) -> Bool in
                return tuple1.1.localizedStandardCompare(tuple2.1) == .orderedAscending
            }
            
            
            
            guard let firstImageEntry = imageEntries.first else {
                print("ZIP中没有找到图片文件: \(url.lastPathComponent)")
                return nil
            }
            
            
            
            var imageData = Data()
            _ = try archive.extract(firstImageEntry.0) { data in
                imageData.append(data)
            }
            
            
            return imageData
            
        } catch {
            print("ZIP解压失败: \(error)")
            return nil
        }
    }

    static func getAllImagesFromZip(at url: URL) -> [(path: String, data: Data)] {
        
        
        do {
            let archive = try Archive(url: url, accessMode: .read)
            let imageExtensions = ["jpg", "jpeg", "png", "webp", "gif", "bmp"]
            var images: [(path: String, data: Data)] = []
            
            // 获取所有图片文件并按自然排序
            let imageEntries = archive.compactMap { entry -> (Entry, String)? in
                let pathExtension = URL(fileURLWithPath: entry.path).pathExtension.lowercased()
                if imageExtensions.contains(pathExtension) {
                    return (entry, entry.path)
                }
                return nil
            }.sorted { (tuple1: (Entry, String), tuple2: (Entry, String)) -> Bool in
                return tuple1.1.localizedStandardCompare(tuple2.1) == .orderedAscending
            }
            
            
            
            for (entry, path) in imageEntries {
                var imageData = Data()
                _ = try archive.extract(entry) { data in
                    imageData.append(data)
                }
                images.append((path: path, data: imageData))
            }
            
            
            return images
        } catch {
            print("ZIP解压失败: \(error)")
            return []
        }
    }
}
