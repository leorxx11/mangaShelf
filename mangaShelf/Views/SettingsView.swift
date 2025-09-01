//
//  SettingsView.swift
//  mangaShelf
//
//  Created by 自动生成 on 2025/8/27.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var mangaStore: MangaStore
    @EnvironmentObject private var uiState: UIState
    @State private var isImporting = false
    @State private var importStatus: String?
    @State private var showClearConfirm = false
    @State private var showCacheClearConfirm = false
    @AppStorage("appTheme") private var appThemeRaw: String = AppTheme.system.rawValue
    // 简化界面后不再需要悬停状态

    var body: some View {
        ZStack {
            List {
                // Appearance settings
                Section {
                    GroupBox {
                        HStack(spacing: 12) {
                            Image(systemName: "paintbrush")
                                .frame(width: 18)
                            Text("主题")
                            Spacer()
                            Picker("主题", selection: $appThemeRaw) {
                                ForEach(AppTheme.allCases) { theme in
                                    Text(theme.title).tag(theme.rawValue)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 240)
                        }
                        .padding(.vertical, 6)
                    } label: {
                        Text("外观")
                    }
                }
                .listRowSeparator(.hidden)

                // Import group boxed (rows merged in one card)
                Section {
                    GroupBox {
                        VStack(spacing: 0) {
                            SettingsRowButton(system: "doc.badge.plus", title: "导入文件 - 复制") {
                                pickAndCopyFiles()
                            }
                            Divider()
                            SettingsRowButton(system: "folder.badge.plus", title: "导入文件夹 - 复制") {
                                pickAndCopyFolders()
                            }
                            Divider()
                            SettingsRowButton(system: "externaldrive.connected.to.line.below", title: "挂载文件夹 - 直接读取") {
                                pickAndMountFolder()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } label: {
                        Text("导入")
                    }
                }
                .listRowSeparator(.hidden)

                // Library utilities boxed
                Section {
                    GroupBox {
                        VStack(spacing: 0) {
                            SettingsRowButton(system: "folder", title: "打开存储目录") {
                                openLibraryFolder()
                            }
                            Divider()
                            SettingsRowButton(system: "wand.and.stars", title: "清理缓存") {
                                showCacheClearConfirm = true
                            }
                            Divider()
                            SettingsRowButton(system: "trash", title: "清除所有漫画", isDestructive: true, isDisabled: mangaStore.mangas.isEmpty) {
                                showClearConfirm = true
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    } label: {
                        Text("图书馆")
                    }
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.inset)
            .alert("确认清理缓存？", isPresented: $showCacheClearConfirm) {
                Button("清理", role: .destructive) {
                    ImageCacheManager.shared.clearCache()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("删除封面、页面、缩略图缓存；不影响已导入漫画。清理后首开稍慢，缓存将自动重建。")
            }
            .alert("确认清除所有漫画？", isPresented: $showClearConfirm) {
                Button("清除", role: .destructive) {
                    mangaStore.clearMangas()
                    uiState.shelfPath.removeAll()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("这将清空应用内的漫画列表与缓存，不会删除原始文件。")
            }
            
            if isImporting {
                Color.black.opacity(0.06)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                ImportHUD(text: importStatus ?? "正在导入…")
            }
        }
    }

    // MARK: - Row helpers
    @ViewBuilder
    private func rowLabel(system: String, title: String) -> some View {
        HStack {
            Image(systemName: system)
                .frame(width: 18)
            Text(title)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }

    private struct SettingsRowButton: View {
        let system: String
        let title: String
        var isDestructive: Bool = false
        var isDisabled: Bool = false
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: system)
                        .frame(width: 18)
                    Text(title)
                        .foregroundColor(isDestructive ? .red : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
        }
    }

    private struct ImportHUD: View {
        let text: String
        var body: some View {
            VStack(spacing: 10) {
                ProgressView().controlSize(.large)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 8)
        }
    }

    // 仅保留已实现的行，未实现的入口已从列表移除

    // MARK: - Actions
    private func pickAndMountFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK, let folder = panel.urls.first {
            let accessed = folder.startAccessingSecurityScopedResource()
            Task {
                await MainActor.run {
                    isImporting = true
                    importStatus = "正在扫描..."
                }
                // 让 UI 有机会先渲染出进度条
                await Task.yield()
                let scanned = await Task.detached(priority: .userInitiated) {
                    MangaScanner.scanDirectory(at: folder)
                }.value
                await MainActor.run {
                    mangaStore.setMangas(scanned)
                    isImporting = false
                    importStatus = nil
                }
                if accessed { folder.stopAccessingSecurityScopedResource() }
            }
        }
    }

    private func pickAndCopyFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = allowedArchiveTypes()
        } else {
            panel.allowedFileTypes = ["zip", "cbz"]
        }
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            let urls = panel.urls
            Task { await copyItems(urls: urls, treatAsFolder: false) }
        }
    }

    private func pickAndCopyFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "导入"
        if panel.runModal() == .OK {
            let urls = panel.urls
            Task { await copyItems(urls: urls, treatAsFolder: true) }
        }
    }

    private func copyItems(urls: [URL], treatAsFolder: Bool) async {
        let fm = FileManager.default
        guard let libraryRoot = appLibraryRoot() else { return }
        do { try fm.createDirectory(at: libraryRoot, withIntermediateDirectories: true) } catch { }

        await MainActor.run {
            isImporting = true
            importStatus = "正在复制 \(urls.count) 项..."
        }
        // 让 UI 先刷新再进行大量 IO
        await Task.yield()

        var index = 1
        for url in urls {
            await MainActor.run {
                importStatus = "正在复制 (\(index)/\(urls.count))：\(url.lastPathComponent)"
            }
            await Task.yield()
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let dest = libraryRoot.appendingPathComponent(url.lastPathComponent)
            // 避免重名
            let uniqueDest = uniqueURL(for: dest)

            do {
                if treatAsFolder {
                    try fm.copyItem(at: url, to: uniqueDest)
                } else {
                    try fm.copyItem(at: url, to: uniqueDest)
                }
            } catch {
                print("复制失败: \(url.lastPathComponent) -> \(error)")
            }
            index += 1
        }
        await MainActor.run {
            importStatus = "正在扫描..."
        }

        // 复制完成后，扫描 App Library
        let scanned = await Task.detached(priority: .userInitiated) {
            MangaScanner.scanDirectory(at: libraryRoot)
        }.value
        await MainActor.run {
            mangaStore.setMangas(scanned)
            isImporting = false
            importStatus = nil
        }
    }

    private func appLibraryRoot() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("mangaShelf/Library", isDirectory: true)
    }

    private func uniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        var candidate = url
        var count = 1
        while fm.fileExists(atPath: candidate.path) {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = ext.isEmpty ? "\(name) \(count)" : "\(name) \(count).\(ext)"
            candidate = url.deletingLastPathComponent().appendingPathComponent(newName)
            count += 1
        }
        return candidate
    }

    private func openLibraryFolder() {
        guard let url = appLibraryRoot() else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// 预览
#Preview { SettingsView().environmentObject(MangaStore()) }

// WiFi 传书已取消，不再包含相关 UI

// 支持 zip/cbz 选择
private func allowedArchiveTypes() -> [UTType] {
    var types: [UTType] = [UTType.zip]
    if let cbz = UTType(filenameExtension: "cbz") { types.append(cbz) }
    return types
}
