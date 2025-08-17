# mangaShelf

一个优雅的 macOS 本地漫画阅读器，支持文件夹和 ZIP 格式漫画的管理与阅读。

![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2013.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## ✨ 特性

### 📚 多格式支持
- **文件夹漫画**: 包含图片文件和 `cover` 封面的目录
- **ZIP 压缩包**: 内含图片的 ZIP 档案（自动使用第一张图片作为封面）
- **系列集合**: 包含多个漫画的文件夹，支持混合格式

### 📖 阅读体验
- **连续阅读模式**: 类似 Webtoon 的垂直滚动阅读
- **全屏模式**: 点击漫画页面切换全屏/窗口模式
- **阅读进度**: 自动记录和恢复阅读位置
- **智能布局**: 图片自动适配窗口宽度

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
1. **导入漫画库**: 启动应用后，选择包含漫画的根目录
2. **浏览漫画**: 在书架界面浏览已导入的漫画
3. **开始阅读**: 点击漫画封面进入阅读界面
4. **全屏阅读**: 点击漫画页面切换全屏模式

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
- **MangaScanner**: 递归扫描目录，识别漫画类型
- **MangaStore**: 管理漫画库状态（ObservableObject）
- **MangaPageLoader**: 异步加载漫画页面
- **ImageCacheManager**: 图片缓存和 ZIP 解压管理
- **ReadingProgressManager**: 阅读进度追踪

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
- 所有文件操作都包装在安全作用域中
- 支持 App Sandbox 限制环境

## 🐛 已知问题

1. **阅读进度**: 当前版本不会持久化阅读进度，重启应用后会重置
2. **内存使用**: 大型图片可能消耗较多内存
3. **配置路径**: 存在硬编码路径，需要改为用户配置

## 🔧 故障排除

### 无法导入漫画
- 确保文件夹包含支持的图片格式（JPG, PNG, WebP）
- 检查文件夹漫画是否有 `cover` 封面文件
- 验证 ZIP 文件未损坏

### 图片显示问题
- 确认图片文件未损坏
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