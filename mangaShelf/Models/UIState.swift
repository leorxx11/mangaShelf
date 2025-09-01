//
//  UIState.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/27.
//

import Foundation
import SwiftUI

class UIState: ObservableObject {
    @Published var showBottomBar: Bool = true
    // 书架导航路径：用于在 Tab 间切换时记忆位置
    @Published var shelfPath: [ShelfRoute] = []
}
