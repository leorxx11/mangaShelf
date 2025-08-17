# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mangaShelf is a macOS SwiftUI application for managing and reading local manga collections. It supports two manga storage formats:
- **Folder manga**: Directories containing images with a `cover` image file for the thumbnail
- **ZIP manga**: ZIP archives containing images, using the first image as cover
- **Series folders**: Directories containing multiple manga (folders or ZIPs) grouped together

## Build and Development Commands

**Building:**
```bash
# Open in Xcode
open mangaShelf.xcodeproj

# Build from command line
xcodebuild -scheme mangaShelf -destination 'platform=macOS' build

# Run tests
xcodebuild test -scheme mangaShelf -destination 'platform=macOS'
```

**No linting or formatting commands** - uses standard Swift/Xcode formatting.

## Architecture Overview

### Core Data Flow
1. **MangaScanner** recursively scans directories to identify manga types
2. **MangaStore** (@Published ObservableObject) manages the manga collection state  
3. **ImageCacheManager** handles cover image caching and extraction from ZIPs
4. **MangaPageLoader** loads individual pages for reading (supports both folder and ZIP sources)
5. **ReadingProgressManager** tracks reading position across app sessions

### Key Architectural Patterns

**Security-Scoped Resource Access**: All file operations use `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` pattern for sandbox compatibility.

**Async Image Loading**: Images are loaded asynchronously with caching. ZIP images are extracted to temporary cache files.

**Navigation Structure**: 
- `ContentView` → `MangaShelfView` (main library)
- `MangaShelfView` → `SubShelfView` (for series with multiple manga)  
- `SubShelfView` → `MangaReaderView` (individual manga reading)

**State Management**: Uses SwiftUI's `@StateObject`, `@ObservedObject`, and `@Published` for reactive UI updates. No external state management frameworks.

### Critical Implementation Details

**Manga Type Detection Logic** (`MangaScanner.swift`):
- Series folders: Contains 2+ subdirectories/ZIPs with no non-cover images at root level
- Folder manga: Directory with images and a `cover.*` file
- ZIP manga: `.zip` extension

**Reader Interface** (`MangaReaderView.swift`):
- Webtoon-style vertical scrolling reader
- Top toolbar shows/hides with fullscreen toggle (tap images to toggle)
- Uses `PlainButtonStyle()` to avoid double backgrounds on buttons
- Custom `AppTopBar` component for consistent navigation

**File Access Pattern**: Always wrap file operations with security-scoped resource access, especially when scanning directories or reading from user-selected folders.

## Testing Notes

Run tests through Xcode or command line. Tests are located in `mangaShelfTests/` and `mangaShelfUITests/`. No special test configuration required.

## Important Constraints

- **macOS only**: Uses `NSImage` and macOS-specific file APIs
- **Local files only**: No network functionality  
- **SwiftUI native**: No UIKit bridging
- **Security scoped**: Must handle file access permissions properly for user-selected directories