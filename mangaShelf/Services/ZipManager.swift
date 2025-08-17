//
//  ZipManager.swift
//  mangaShelf
//
//  Created by 赵粒宇 on 2025/8/17.
//

import Foundation
import ZIPFoundation

class ZipManager {
    static func getFirstImageFromZip(at url: URL) -> Data? {
        print("🗜️ 开始从ZIP提取封面: \(url.lastPathComponent)")
        
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
            
            print("🗜️ ZIP中找到 \(imageEntries.count) 个图片文件")
            
            guard let firstImageEntry = imageEntries.first else {
                print("🗜️ ❌ ZIP中没有找到图片文件")
                return nil
            }
            
            print("🗜️ 提取第一张图片: \(firstImageEntry.1)")
            
            var imageData = Data()
            _ = try archive.extract(firstImageEntry.0) { data in
                imageData.append(data)
            }
            
            print("🗜️ ✅ 成功提取图片，大小: \(imageData.count) 字节")
            return imageData
            
        } catch {
            print("🗜️ ❌ ZIP解压失败: \(error)")
            return nil
        }
    }
    
    static func getAllImagesFromZip(at url: URL) -> [(path: String, data: Data)] {
        print("🗜️ 开始从ZIP提取所有图片: \(url.lastPathComponent)")
        
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
            
            print("🗜️ ZIP中找到 \(imageEntries.count) 个图片条目")
            
            for (entry, path) in imageEntries {
                var imageData = Data()
                _ = try archive.extract(entry) { data in
                    imageData.append(data)
                }
                images.append((path: path, data: imageData))
                print("🗜️ 提取图片: \(path), 大小: \(imageData.count) 字节")
            }
            
            print("🗜️ ✅ 成功提取 \(images.count) 个图片")
            return images
        } catch {
            print("🗜️ ❌ ZIP解压失败: \(error)")
            return []
        }
    }
}