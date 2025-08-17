# Repository Guidelines

## Project Structure & Module Organization
- `mangaShelf/`: App source code.
  - `Views/`: SwiftUI screens (MangaShelfView, SubShelfView, MangaReaderView, AppTopBar).
  - `Services/`: IO, caching, and parsing (Scanner, PageLoader, ImageCache, Zip).
  - `Models/`: Data models and state (Manga, ReadingProgress).
  - `Assets.xcassets/`: App assets.
  - Root files: `mangaShelfApp.swift`, `ContentView.swift`, entitlements.
- `mangaShelf.xcodeproj/`: Xcode project.
- `mangaShelfTests/`, `mangaShelfUITests/`: Unit/UI tests.

## Build, Test, and Development Commands
- Open in Xcode: `open mangaShelf.xcodeproj`
- Build (CLI): `xcodebuild -scheme mangaShelf -destination 'platform=macOS' build`
- Run tests: `xcodebuild test -scheme mangaShelf -destination 'platform=macOS'`
- Launch locally: run the app target from Xcode (macOS). Use a folder with comics for import.

## Coding Style & Naming Conventions
- Language: Swift 5, SwiftUI. Indent with 4 spaces; line length ≈ 120.
- Names: `UpperCamelCase` for types/files, `lowerCamelCase` for vars/functions, `SCREAMING_SNAKE_CASE` for constants if needed.
- Views: compose with small SwiftUI views; keep business logic in `Services/`.
- Navigation: prefer `NavigationStack` + visible `NavigationLink`. Do not use hidden NavigationLinks or programmatic `isActive` hacks.
- Top bar: use `AppTopBar` for consistent height/behavior. Hide system back arrow and implement custom back via `@Environment(\.dismiss)`.
- Avoid raw `print` inside ViewBuilder expressions (e.g., `NavigationLink { ... }`).

## Testing Guidelines
- Frameworks: XCTest for unit tests, XCUITest for UI.
- Structure: place tests in `mangaShelfTests/` and `mangaShelfUITests/`; name files `*Tests.swift`.
- Run often: `xcodebuild test ...` or from Xcode. Keep tests deterministic; avoid touching real user folders.

## Commit & Pull Request Guidelines
- Commits: concise, imperative. Suggested prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`.
- PRs: include summary, screenshots for UI changes, steps to test, and link related issues. Keep diffs focused; avoid unrelated refactors.

## Security & Configuration Tips
- File access: when reading outside app sandbox, use security-scoped resources and always balance `startAccessing...` with `stopAccessing...`.
- Performance: use `LazyVGrid/LazyVStack` for long lists and cache images via `ImageCacheManager`.

