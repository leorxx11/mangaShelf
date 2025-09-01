//
//  ImageDecode.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/29.
//

import Foundation
import AppKit
import ImageIO

enum ImageDecode {
    static func fromData(_ data: Data) -> NSImage? {
        let cfData = data as CFData
        guard let src = CGImageSourceCreateWithData(cfData, nil) else { return NSImage(data: data) }
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true] as CFDictionary) else {
            return NSImage(data: data)
        }
        return NSImage(cgImage: cg, size: .zero)
    }

    static func fromURL(_ url: URL) -> NSImage? {
        // 优先读取数据再解码，避免 CGImageSource 直接 mmap URL 触发权限问题
        if let data = try? Data(contentsOf: url) {
            return fromData(data)
        }
        // 回退到 URL 解码（若权限允许）
        let cfURL = url as CFURL
        if let src = CGImageSourceCreateWithURL(cfURL, nil),
           let cg = CGImageSourceCreateImageAtIndex(src, 0, [kCGImageSourceShouldCache: true] as CFDictionary) {
            return NSImage(cgImage: cg, size: .zero)
        }
        return nil
    }

    // 生成缩略图（最长边不超过 maxPixel），返回 JPEG 数据
    static func thumbnailData(from data: Data, maxPixel: Int) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }
        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])
    }
    
    static func thumbnailData(fromFile url: URL, maxPixel: Int) -> Data? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return thumbnailData(from: data, maxPixel: maxPixel)
    }
}
