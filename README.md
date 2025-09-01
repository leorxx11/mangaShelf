# mangaShelf

一个优雅的 macOS 本地漫画阅读器，支持文件夹和 ZIP 格式漫画的管理与阅读。

![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ 特性

### 📚 多格式支持
- **文件夹漫画**: 包含图片文件和 `cover` 封面的目录
- **ZIP/CBZ**: 内含图片的压缩包（优先 `cover.*`，否则第一张图片作封面）
- **系列集合（混合）**: 一个目录中可同时包含 ZIP、子文件夹与散图；根层散图会以“单张图片条目”的形式出现在子书架中

### 📖 阅读体验
- **连续阅读模式**: 类似 Webtoon 的垂直滚动阅读
- **全屏模式**: 点击漫画页面切换全屏/窗口模式
- **阅读进度持久化**: 自动记录与恢复阅读位置，重启应用后也会跳转到上次阅读页
- **只读进度条**: 底部显示百分比与“当前/总页”，不可拖动跳页，避免误触
- **原图清晰**: 使用原始分辨率显示（按窗口宽度等比缩放），不进行压缩/下采样
- **智能布局**: 图片自动适配窗口宽度

### 🎨 外观与主题
- **主题切换**: 设置页支持“跟随系统 / 浅色 / 深色”
- **深色优化**: 自定义顶部栏/底部栏在深色下按视觉规范压暗

### 🔐 安全设计
- **沙盒兼容**: 完全支持 macOS 应用沙盒
- **安全文件访问**: 使用 Security-Scoped Resources 访问用户文件
- **只读权限**: 仅读取文件，不修改用户数据

## 🖥️ 系统要求

- **系统**: macOS 13.0 或更高版本
- **架构**: 支持 Intel 和 Apple Silicon
- **内存**: 建议 4GB 以上（处理大型图片文件）

## 🚀 快速开始

### 安装
1. 从 [Releases](https://github.com/leorxx11/mangaShelf/releases) 下载最新版本
2. 将应用拖拽到 `应用程序` 文件夹
3. 首次运行时允许从"未知开发者"安装

### 使用方法
1. **导入漫画库**: 启动应用后，点击“导入”选择包含漫画的根目录（将创建安全作用域书签以允许跨重启访问）
2. **浏览漫画**: 在书架界面浏览已导入的漫画（导入的列表默认会持久化保存）
3. **开始阅读**: 点击漫画封面进入阅读界面；退出后会自动保存阅读进度
4. **全屏阅读**: 点击漫画页面切换全屏模式
5. **清除**: 点击“清除”可清空书架并删除本地缓存与授权书签（不会删除原文件）

## 📁 支持的漫画格式

### 文件夹格式
```
漫画名称/
├── cover.jpg          # 封面图片（必需）
├── 001.jpg
├── 002.jpg
└── ...
```

### ZIP 格式
```
漫画名称.zip
├── 001.jpg            # 第一张图片作为封面
├── 002.jpg
└── ...
```

### 系列格式
```
系列名称/
├── cover.jpg          # 系列封面（可选）
├── 第1话/
│   ├── cover.jpg
│   └── *.jpg
├── 第2话.zip
└── ...
```

## 🏗️ 开发构建

### 环境要求
```bash
# 系统要求
macOS 13.0+
Xcode 15.0+
Swift 5.9+
```

### 构建步骤
```bash
# 克隆仓库
git clone https://github.com/leorxx11/mangaShelf.git
cd mangaShelf

# 在 Xcode 中打开
open mangaShelf.xcodeproj

# 或使用命令行构建
xcodebuild -scheme mangaShelf -destination 'platform=macOS' build
```

### 运行测试
```bash
xcodebuild test -scheme mangaShelf -destination 'platform=macOS'
```

## 🏛️ 架构设计

### 核心组件
- **MangaScanner**: 递归扫描目录，识别漫画/系列
- **MangaStore**: 管理漫画库状态（ObservableObject）
- **MangaPageLoader**: 懒加载页面、内存缓存与预取
- **ZipManager**: ZIP 条目枚举与按需解压
- **ImageCacheManager**: 封面与页面的磁盘缓存
- **ReadingProgressManager**: 阅读进度追踪与持久化

### 数据流
```
目录选择 → MangaScanner → MangaStore → UI更新
     ↓
阅读界面 → MangaPageLoader → 图片显示
     ↓
进度更新 → ReadingProgressManager → 持久化存储
```

### 安全模式
- 使用 `startAccessingSecurityScopedResource()` 访问用户文件
- 为导入的根目录保存 Security-Scoped Bookmark，支持跨重启持久授权
- 所有文件操作都包装在安全作用域中
- 支持 App Sandbox 限制环境

## 🐛 已知问题
 
## ⚡ 性能与缓存

- **ZIP 懒加载**: 不一次性解压全部页面，按需解压当前/邻近页面，降低启动与滚动时的 I/O 峰值。
- **页面磁盘缓存**: 每个 ZIP 条目都会缓存到 `~/Library/Caches/MangaPages/<zipBase>_sz<size>_t<mtime>/`，当 ZIP 文件大小或修改时间变化时自动失效重建。
- **封面缓存（v2）**: `~/Library/Caches/MangaCovers/`，文件名包含 ZIP 大小与修改时间，文件变更自动失效。
- **缩略图缓存（新）**: `~/Library/Caches/MangaThumbs/`，为散图卡片生成 320px JPEG 小图，用于列表秒开。
- **生成限流**: 缩略图生成采用并发限流与去重，避免首屏 I/O 风暴。
- **内存缓存与预取**: 使用 `NSCache` 做页面级内存缓存，并在阅读时预取后续 2 页以提升滚动顺滑度。
- **一键清理**: 设置 → 图书馆 → 清理缓存，可清空封面/页面/缩略图缓存；不影响已导入的漫画。

提示：原图清晰度优先，本版本不做下采样；在包含超大分辨率图片的长篇漫画中，内存占用会相应升高。

## 🐛 已知问题

1. **授权问题**: 如果曾在旧版本导入且未保存安全书签，可能出现读取失败（Code=257）。请重新“导入”根目录以更新授权。
2. **内存使用**: 原图显示配合预取会提高内存占用；如遇压力，可减小窗口尺寸或在设置中清理缓存后重进目录。

## 🆕 最近更新（选摘）
- 主题切换（跟随系统/浅色/深色）与深色视觉优化
- 修复“跟随系统”切回无效的问题（环境覆盖 + 视图重建）
- 系列支持根层散图，散图以单独卡片显示
- 封面选择优化：系列递归找 `cover.*` → 依序尝试 ZIP（优先 `cover.*`，否则首图）
- ImageIO 解码路径，提升 WebP/大图的兼容性与稳定性
- 阅读器切换条目自动置顶，避免跳到底部
- 缩略图缓存与并发限流，显著降低首屏卡顿
- 清理缓存入口（封面/页面/缩略图），并加入确认说明
- 书架导航记忆：在 Tab 间切换保持停留层级；清空库时自动回到根目录

## 🔧 故障排除

### 无法导入漫画
- 确保文件夹包含支持的图片格式（JPG, PNG, WebP）
- 检查文件夹漫画是否有 `cover` 封面文件
- 验证 ZIP 文件未损坏

### 图片显示问题
- 确认图片文件未损坏
- 如果提示无权限（Code=257），请重新“导入”根目录以恢复安全授权
- 检查文件权限是否正确
- 重启应用重新加载图片缓存

## 🤝 贡献

欢迎提交 Pull Request 和 Issue！

### 开发指南
1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 代码规范
- 使用 4 空格缩进
- 遵循 Swift API 设计指南
- 添加必要的注释和文档

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) - ZIP 文件处理
- SwiftUI - 现代化的用户界面框架

## 📞 联系

- GitHub Issues: [提交问题](https://github.com/leorxx11/mangaShelf/issues)
- GitHub Discussions: [参与讨论](https://github.com/leorxx11/mangaShelf/discussions)

---

**注意**: 本应用仅用于阅读个人拥有的漫画文件，请遵守相关版权法律法规。
