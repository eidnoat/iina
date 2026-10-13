//
//  CollectionDetailView.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI
import Cocoa

public struct CollectionDetailView: View {
  let collection: MediaCollection
  let category: MediaCategory
  @ObservedObject var manager: CollectionManager
  let onBack: () -> Void
  let onEdit: () -> Void

  @State private var hoveredEpisodeId: UUID?
  @State private var episodeThumbnails: [UUID: NSImage] = [:]

  public var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      VStack(alignment: .leading, spacing: 28) {
        // 顶部返回与导航工具栏
        topActionBar

        // 沉浸式海报与头部信息
        heroHeaderView

        // 分集列表区域
        episodesSectionView

        Spacer(minLength: 40)
      }
      .padding(.horizontal, 28)
      .padding(.top, 16)
    }
    .background(CollectionTheme.darkBackground.edgesIgnoringSafeArea(.all))
    .onAppear {
      loadThumbnails()
    }
  }

  // MARK: - Top Action Bar

  private var topActionBar: some View {
    HStack {
      Button(action: onBack) {
        HStack(spacing: 6) {
          Image(systemName: "chevron.left")
            .font(.system(size: 13, weight: .bold))
          Text(category.name)
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
      }
      .buttonStyle(PlainButtonStyle())

      Spacer()

      Button(action: onEdit) {
        HStack(spacing: 6) {
          Image(systemName: "pencil")
          Text("编辑系列")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .cornerRadius(8)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  // MARK: - Hero Header View

  private var heroHeaderView: some View {
    HStack(alignment: .top, spacing: 28) {
      // 封面海报
      ZStack {
        posterView
          .aspectRatio(CollectionTheme.posterAspectRatio, contentMode: .fit)
          .frame(width: 170)
          .cornerRadius(CollectionTheme.cardCornerRadius)
          .shadow(color: Color.black.opacity(0.5), radius: 14, y: 6)
      }

      // 系列文字信息与操作
      VStack(alignment: .leading, spacing: 12) {
        Text(collection.title)
          .font(.system(size: 26, weight: .bold))
          .foregroundColor(.white)

        if let original = collection.originalTitle, !original.isEmpty {
          Text(original)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.secondary)
        }

        // 标签栏
        HStack(spacing: 12) {
          if let year = collection.year, !year.isEmpty {
            badgeTag(year)
          }
          badgeTag("共 \(collection.episodes.count) 集")
          if collection.isAllFinished {
            badgeTag("全剧已看完", color: .green)
          } else if collection.unwatchedCount > 0 {
            badgeTag("剩余 \(collection.unwatchedCount) 集未看", color: CollectionTheme.accentColor)
          }
        }

        if let summary = collection.summary, !summary.isEmpty {
          Text(summary)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .lineSpacing(4)
            .padding(.top, 4)
            .lineLimit(4)
        }

        Spacer(minLength: 8)

        // 播放主按钮
        playButtonsView
      }

      Spacer()
    }
    .padding(20)
    .background(
      ZStack {
        // 背景高斯模糊横幅
        if let backdropImage = getBackdropOrCoverImage() {
          Image(nsImage: backdropImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .blur(radius: 50)
            .opacity(0.25)
            .clipped()
        }
        RoundedRectangle(cornerRadius: 16)
          .fill(CollectionTheme.darkCardBackground.opacity(0.75))
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(Color.white.opacity(0.08), lineWidth: 1)
          )
      }
    )
    .cornerRadius(16)
  }

  // MARK: - Play Buttons

  private var playButtonsView: some View {
    HStack(spacing: 14) {
      if let nextEp = collection.nextEpisodeToPlay {
        Button(action: {
          manager.play(collection: collection, startingFrom: nextEp)
        }) {
          HStack(spacing: 8) {
            Image(systemName: "play.fill")
              .font(.system(size: 14))
            Text(nextEp.lastPlayedTime > 5.0 ? "继续播放 第 \(nextEp.episodeNumber) 集" : "开始播放 第 \(nextEp.episodeNumber) 集")
              .font(.system(size: 13, weight: .semibold))
          }
          .foregroundColor(.white)
          .padding(.horizontal, 18)
          .padding(.vertical, 10)
          .background(CollectionTheme.accentGradient)
          .cornerRadius(20)
          .shadow(color: CollectionTheme.accentColor.opacity(0.35), radius: 8, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
      }

      // 快捷添加视频按钮
      Button(action: {
        promptAddEpisodes()
      }) {
        HStack(spacing: 6) {
          Image(systemName: "plus")
          Text("添加视频文件")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.12))
        .cornerRadius(20)
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

  // MARK: - Episodes Section

  private var episodesSectionView: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("分集剧目 (\(collection.episodes.count))")
          .font(.system(size: 18, weight: .bold))
          .foregroundColor(.white)
        Spacer()
      }

      if collection.episodes.isEmpty {
        VStack(spacing: 12) {
          Text("该系列暂未添加视频文件")
            .font(.subheadline)
            .foregroundColor(.secondary)
          Button("选择视频文件导入") {
            promptAddEpisodes()
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
      } else {
        // 分集网格/横向卡片流
        let epColumns = [
          GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 18)
        ]

        LazyVGrid(columns: epColumns, spacing: 18) {
          ForEach(collection.episodes) { episode in
            EpisodeCard(
              episode: episode,
              thumbnail: episodeThumbnails[episode.id],
              isHovered: hoveredEpisodeId == episode.id,
              onPlay: {
                manager.play(collection: collection, startingFrom: episode)
              },
              onShowInFinder: {
                NSWorkspace.shared.selectFile(episode.filePath, inFileViewerRootedAtPath: "")
              },
              onRemove: {
                manager.removeEpisode(episodeId: episode.id, collectionId: collection.id, categoryId: category.id)
              }
            )
            .onHover { isHovered in
              withAnimation(.easeInOut(duration: 0.15)) {
                hoveredEpisodeId = isHovered ? episode.id : nil
              }
            }
          }
        }
      }
    }
  }

  // MARK: - Helpers

  private func badgeTag(_ text: String, color: Color = .white.opacity(0.8)) -> some View {
    Text(text)
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.white.opacity(0.08))
      .cornerRadius(4)
  }

  @ViewBuilder
  private var posterView: some View {
    if let coverFilename = collection.coverFilename,
       let imageURL = manager.imageURL(for: coverFilename, in: manager.coversDirectoryURL),
       let nsImage = NSImage(contentsOf: imageURL) {
      Image(nsImage: nsImage)
        .resizable()
        .aspectRatio(contentMode: .fill)
    } else {
      ZStack {
        CollectionTheme.darkCardBackground
        Image(systemName: "film")
          .font(.system(size: 40))
          .foregroundColor(.secondary.opacity(0.4))
      }
    }
  }

  private func getBackdropOrCoverImage() -> NSImage? {
    if let backdropFilename = collection.backdropFilename,
       let url = manager.imageURL(for: backdropFilename, in: manager.backdropsDirectoryURL),
       let img = NSImage(contentsOf: url) {
      return img
    }
    if let coverFilename = collection.coverFilename,
       let url = manager.imageURL(for: coverFilename, in: manager.coversDirectoryURL),
       let img = NSImage(contentsOf: url) {
      return img
    }
    return nil
  }

  private func loadThumbnails() {
    DispatchQueue.global(qos: .userInitiated).async {
      for ep in collection.episodes {
        if episodeThumbnails[ep.id] == nil && ep.fileExists {
          if let thumb = manager.generateThumbnail(for: ep.filePath, at: 15.0) {
            DispatchQueue.main.async {
              self.episodeThumbnails[ep.id] = thumb
            }
          }
        }
      }
    }
  }

  private func promptAddEpisodes() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = true
    panel.title = "选择要导入该系列的视频文件或文件夹"

    if panel.runModal() == .OK {
      var allFilePaths: [String] = []
      for url in panel.urls {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
          allFilePaths.append(contentsOf: manager.scanPlayableFilesInDirectory(url))
        } else {
          allFilePaths.append(url.path)
        }
      }
      manager.addEpisodes(to: collection.id, in: category.id, filePaths: allFilePaths)
      loadThumbnails()
    }
  }
}

// MARK: - Episode Card

struct EpisodeCard: View {
  let episode: MediaEpisode
  let thumbnail: NSImage?
  let isHovered: Bool
  let onPlay: () -> Void
  let onShowInFinder: () -> Void
  let onRemove: () -> Void

  var body: some View {
    Button(action: onPlay) {
      VStack(alignment: .leading, spacing: 8) {
        // 16:9 缩略图容器
        ZStack(alignment: .bottomLeading) {
          ZStack {
            if let thumbnail {
              Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
            } else {
              Rectangle()
                .fill(Color(red: 0.12, green: 0.13, blue: 0.16))
              Image(systemName: "play.tv")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.4))
            }
          }
          .aspectRatio(CollectionTheme.episodeAspectRatio, contentMode: .fit)
          .cornerRadius(8)
          .clipped()
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
          )

          // 悬浮集数标签
          Text("E\(episode.episodeNumber)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.75))
            .cornerRadius(4)
            .padding(6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

          // 播放悬停图标
          if isHovered {
            ZStack {
              Circle()
                .fill(Color.black.opacity(0.65))
                .frame(width: 36, height: 36)
              Image(systemName: "play.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
          }

          // 进度细线
          if episode.progressRatio > 0 {
            GeometryReader { geo in
              VStack {
                Spacer()
                ZStack(alignment: .leading) {
                  Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 3)
                  Rectangle()
                    .fill(episode.isFinished ? Color.green : CollectionTheme.accentColor)
                    .frame(width: geo.size.width * CGFloat(episode.progressRatio), height: 3)
                }
              }
            }
            .cornerRadius(8)
          }
        }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isHovered)

        // 分集标题与时长
        VStack(alignment: .leading, spacing: 2) {
          Text(episode.title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(1)

          HStack {
            Text(episode.formattedProgress)
              .font(.system(size: 11))
              .foregroundColor(episode.isFinished ? .green : .secondary)

            Spacer()

            if episode.duration > 0 {
              Text(episode.formattedDuration)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .buttonStyle(PlainButtonStyle())
    .contextMenu {
      Button(action: onPlay) {
        Label("播放此集", systemImage: "play.fill")
      }
      if episode.fileExists {
        Button(action: onShowInFinder) {
          Label("在访达中显示", systemImage: "folder")
        }
      }
      Divider()
      Button(role: .destructive, action: onRemove) {
        Label("从此系列移除", systemImage: "trash")
      }
    }
  }
}
