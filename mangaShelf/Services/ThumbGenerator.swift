//
//  ThumbGenerator.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/29.
//

import Foundation

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    init(value: Int) { self.value = value }
    func wait() async {
        if value > 0 { value -= 1; return }
        await withCheckedContinuation { cont in waiters.append(cont) }
    }
    func signal() {
        if !waiters.isEmpty {
            let c = waiters.removeFirst()
            c.resume()
        } else {
            value += 1
        }
    }
}

actor ThumbGenerator {
    static let shared = ThumbGenerator()
    private let sem = AsyncSemaphore(value: 3) // 限制同时生成的缩略图数量
    private var inFlight: Set<String> = []

    func generate(key: String, work: @Sendable @escaping () async -> Void) async {
        if inFlight.contains(key) { return }
        inFlight.insert(key)
        await sem.wait()
        Task.detached(priority: .utility) { [weak self] in
            await work()
            await self?.finish(key: key)
        }
    }

    private func finish(key: String) async {
        inFlight.remove(key)
        await sem.signal()
    }
}
