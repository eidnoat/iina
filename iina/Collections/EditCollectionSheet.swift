//
//  EditCollectionSheet.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI
import Cocoa

public struct EditCollectionSheet: View {
  @ObservedObject var manager: CollectionManager
  let currentCategoryId: UUID
  let editingCollection: MediaCollection?
  let onDismiss: () -> Void

  @State private var selectedCategoryId: UUID
  @State private var title: String = ""
  @State private var originalTitle: String = ""
  @State private var year: String = ""
  @State private var summary: String = ""
  @State private var coverImage: NSImage?
  @State private var backdropImage: NSImage?

  @State private var episodes: [MediaEpisode] = []

  public init(
    manager: CollectionManager,
    currentCategoryId: UUID,
    editingCollection: MediaCollection? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.manager = manager
    self.currentCategoryId = currentCategoryId
    self.editingCollection = editingCollection
    self.onDismiss = onDismiss
    _selectedCategoryId = State(initialValue: currentCategoryId)
  }

  public var body: some View {
    VStack(spacing: 0) {
      // 顶栏
      sheetHeader

      Divider()

      // 主体表单
      ScrollView(.vertical, showsIndicators: true) {
        VStack(alignment: .leading, spacing: 20) {
          // 分类选择
          categoryPickerSection

          // 基本信息
          basicInfoSection

          // 海报设置
          mediaCoversSection

          // 分集视频管理
          episodesManagerSection
        }
        .padding(24)
      }

      Divider()

      // 底部操作按钮
      sheetFooter
    }
    .frame(width: 580, height: 680)
    .background(CollectionTheme.darkBackground)
    .onAppear {
      loadInitialData()
    }
  }

  // MARK: - Sections

  private var sheetHeader: some View {
    HStack {
      Text(editingCollection == nil ? "新建系列收藏" : "编辑系列信息")
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
      Spacer()
      Button("取消") {
        onDismiss()
      }
      .keyboardShortcut(.cancelAction)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }

  private var categoryPickerSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("所属分类")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)

      Picker("", selection: $selectedCategoryId) {
        ForEach(manager.categories) { cat in
          HStack {
            Image(systemName: cat.iconName)
            Text(cat.name)
          }
          .tag(cat.id)
        }
      }
      .pickerStyle(MenuPickerStyle())
    }
  }

  private var basicInfoSection: some View {
    VStack(alignment: .leading, spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        Text("系列标题 *")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.secondary)
        TextField("例如：绝命毒师 第一季 / 指环王", text: $title)
          .textFieldStyle(RoundedBorderTextFieldStyle())
      }

      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("英文 / 原名")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          TextField("例如：Breaking Bad", text: $originalTitle)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        VStack(alignment: .leading, spacing: 6) {
          Text("发行年份")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          TextField("例如：2008", text: $year)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 120)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("剧情简介")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.secondary)
        TextEditor(text: $summary)
          .font(.system(size: 12))
          .frame(height: 70)
          .cornerRadius(6)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.1), lineWidth: 1))
      }
    }
  }

  private var mediaCoversSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("海报与封面")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.secondary)

      HStack(spacing: 20) {
        // 海报预览与上传
        VStack(spacing: 8) {
          ZStack {
            if let coverImage {
              Image(nsImage: coverImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
            } else {
              Rectangle()
                .fill(Color.white.opacity(0.06))
              Image(systemName: "photo")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            }
          }
          .frame(width: 90, height: 135)
          .cornerRadius(8)
          .clipped()
          .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.15), lineWidth: 1))

          HStack(spacing: 8) {
            Button("选择图片…") {
              chooseImage { self.coverImage = $0 }
            }
            .font(.system(size: 11))

            if !episodes.isEmpty {
              Button("从视频截帧") {
                if let firstEp = episodes.first,
                   let frame = manager.generateThumbnail(for: firstEp.filePath, at: 10.0) {
                  self.coverImage = frame
                }
              }
              .font(.system(size: 11))
            }
          }
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("封面小提示：")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.primary)
          Text("• 支持选择本地海报图片（建议 2:3 纵向比例）\n• 若添加了视频文件，可直接点击「从视频截帧」一键提取精彩封面\n• 支持常见 JPG、PNG、WEBP 格式")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .lineSpacing(3)
        }

        Spacer()
      }
      .padding(12)
      .background(Color.white.opacity(0.04))
      .cornerRadius(8)
    }
  }

  private var episodesManagerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("分集视频 (\(episodes.count))")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.secondary)

        Spacer()

        Button(action: addFilesAction) {
          HStack(spacing: 4) {
            Image(systemName: "plus")
            Text("添加视频文件 / 文件夹")
          }
          .font(.system(size: 11))
        }
      }

      if episodes.isEmpty {
        VStack(spacing: 8) {
          Text("暂未添加视频文件")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
          Text("点击右上角添加视频，系统会自动识别并排序分集")
            .font(.system(size: 11))
            .foregroundColor(.secondary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
      } else {
        VStack(spacing: 6) {
          ForEach(Array(episodes.enumerated()), id: \.element.id) { index, ep in
            HStack(spacing: 10) {
              Text("E\(ep.episodeNumber)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(CollectionTheme.accentColor)
                .frame(width: 32, alignment: .leading)

              TextField("分集标题", text: Binding(
                get: { ep.title },
                set: { episodes[index].title = $0 }
              ))
              .font(.system(size: 12))
              .textFieldStyle(RoundedBorderTextFieldStyle())

              Button(action: {
                episodes.remove(at: index)
              }) {
                Image(systemName: "minus.circle")
                  .foregroundColor(.red.opacity(0.8))
              }
              .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
          }
        }
      }
    }
  }

  private var sheetFooter: some View {
    HStack {
      Spacer()
      Button("取消") {
        onDismiss()
      }
      Button("保存") {
        saveAction()
      }
      .keyboardShortcut(.defaultAction)
      .buttonStyle(BorderedProminentButtonStyle())
      .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
  }

  // MARK: - Actions

  private func loadInitialData() {
    if let editingCollection {
      title = editingCollection.title
      originalTitle = editingCollection.originalTitle ?? ""
      year = editingCollection.year ?? ""
      summary = editingCollection.summary ?? ""
      episodes = editingCollection.episodes

      if let coverName = editingCollection.coverFilename,
         let url = manager.imageURL(for: coverName, in: manager.coversDirectoryURL) {
        coverImage = NSImage(contentsOf: url)
      }
    }
  }

  private func addFilesAction() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.title = "选择视频文件或剧集文件夹"

    if panel.runModal() == .OK {
      var paths: [String] = []
      for url in panel.urls {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
          paths.append(contentsOf: manager.scanPlayableFilesInDirectory(url))
        } else {
          paths.append(url.path)
        }
      }

      let sortedPaths = paths.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
      var nextEpNum = (episodes.map(\.episodeNumber).max() ?? 0) + 1

      for path in sortedPaths {
        if !episodes.contains(where: { $0.filePath == path }) {
          let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
          let newEp = MediaEpisode(
            episodeNumber: nextEpNum,
            title: filename,
            filePath: path
          )
          episodes.append(newEp)
          nextEpNum += 1
        }
      }
    }
  }

  private func chooseImage(completion: @escaping (NSImage?) -> Void) {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.image]

    if panel.runModal() == .OK, let url = panel.url {
      completion(NSImage(contentsOf: url))
    }
  }

  private func saveAction() {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTitle.isEmpty else { return }

    if let editing = editingCollection {
      manager.updateCollection(
        collectionId: editing.id,
        in: currentCategoryId,
        title: trimmedTitle,
        originalTitle: originalTitle,
        year: year,
        summary: summary,
        coverImage: coverImage,
        backdropImage: backdropImage,
        targetCategoryId: selectedCategoryId
      )
      // 同步分集
      if let catIdx = manager.categories.firstIndex(where: { $0.id == selectedCategoryId }),
         let colIdx = manager.categories[catIdx].collections.firstIndex(where: { $0.id == editing.id }) {
        manager.categories[catIdx].collections[colIdx].episodes = episodes
        manager.saveData()
      }
    } else {
      _ = manager.addCollection(
        to: selectedCategoryId,
        title: trimmedTitle,
        originalTitle: originalTitle,
        year: year,
        summary: summary,
        coverImage: coverImage,
        backdropImage: backdropImage,
        episodes: episodes
      )
    }

    onDismiss()
  }
}
