//
//  PosterGridView.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI

public struct PosterGridView: View {
  @ObservedObject var manager: CollectionManager
  let category: MediaCategory
  let searchText: String
  let onSelectCollection: (MediaCollection) -> Void
  let onEditCollection: (MediaCollection) -> Void

  @State private var hoveredCollectionId: UUID?

  private let columns = [
    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
  ]

  private var filteredCollections: [MediaCollection] {
    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return category.collections
    }
    let query = searchText.lowercased()
    return category.collections.filter { col in
      col.title.lowercased().contains(query) ||
      (col.originalTitle?.lowercased().contains(query) ?? false) ||
      (col.summary?.lowercased().contains(query) ?? false) ||
      col.episodes.contains(where: { $0.title.lowercased().contains(query) })
    }
  }

  public var body: some View {
    ScrollView(.vertical, showsIndicators: true) {
      if filteredCollections.isEmpty {
        emptyStateView
      } else {
        LazyVGrid(columns: columns, spacing: 24) {
          ForEach(filteredCollections) { collection in
            PosterCard(
              collection: collection,
              manager: manager,
              isHovered: hoveredCollectionId == collection.id,
              onSelect: { onSelectCollection(collection) },
              onEdit: { onEditCollection(collection) }
            )
            .onHover { isHovered in
              withAnimation(.easeInOut(duration: 0.2)) {
                hoveredCollectionId = isHovered ? collection.id : nil
              }
            }
          }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
      }
    }
  }

  @ViewBuilder
  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Spacer(minLength: 60)
      Image(systemName: "film.stack")
        .font(.system(size: 54, weight: .light))
        .foregroundColor(.secondary.opacity(0.6))

      if searchText.isEmpty {
        Text("当前分类下暂无系列收藏")
          .font(.title3)
          .foregroundColor(.secondary)
        Text("点击右上角「+ 新建系列」或从文件夹批量导入开始收藏吧")
          .font(.subheadline)
          .foregroundColor(.secondary.opacity(0.8))
      } else {
        Text("未搜索到相关影视系列")
          .font(.title3)
          .foregroundColor(.secondary)
        Text("请尝试更换搜索关键字")
          .font(.subheadline)
          .foregroundColor(.secondary.opacity(0.8))
      }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Single Poster Card

struct PosterCard: View {
  let collection: MediaCollection
  @ObservedObject var manager: CollectionManager
  let isHovered: Bool
  let onSelect: () -> Void
  let onEdit: () -> Void

  var body: some View {
    Button(action: onSelect) {
      VStack(alignment: .leading, spacing: 8) {
        // 海报主体容器
        ZStack(alignment: .bottomLeading) {
          posterView
            .aspectRatio(CollectionTheme.posterAspectRatio, contentMode: .fit)
            .cornerRadius(CollectionTheme.cardCornerRadius)
            .overlay(
              RoundedRectangle(cornerRadius: CollectionTheme.cardCornerRadius)
                .stroke(isHovered ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(
              color: isHovered ? Color.black.opacity(0.55) : CollectionTheme.cardShadowColor,
              radius: isHovered ? 12 : CollectionTheme.cardShadowRadius,
              y: isHovered ? 6 : CollectionTheme.cardShadowY
            )

          // 悬浮集数/状态徽章
          VStack {
            HStack {
              Spacer()
              if collection.isAllFinished {
                badgeView("已看完", color: .green)
              } else if collection.episodes.count > 1 {
                badgeView("\(collection.episodes.count) 集", color: .black.opacity(0.75))
              } else if collection.episodes.count == 1 {
                badgeView("单集", color: .black.opacity(0.75))
              }
            }
            .padding(8)
            Spacer()
          }

          // 底部整体播放进度条
          if collection.overallProgress > 0 && !collection.isAllFinished {
            GeometryReader { geo in
              VStack {
                Spacer()
                ZStack(alignment: .leading) {
                  Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(height: 4)
                  Rectangle()
                    .fill(CollectionTheme.accentColor)
                    .frame(width: geo.size.width * CGFloat(collection.overallProgress), height: 4)
                }
              }
            }
            .cornerRadius(CollectionTheme.cardCornerRadius)
          }
        }
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHovered)

        // 标题与年份
        VStack(alignment: .leading, spacing: 2) {
          Text(collection.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(1)

          HStack(spacing: 6) {
            if let year = collection.year, !year.isEmpty {
              Text(year)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            if let originalTitle = collection.originalTitle, !originalTitle.isEmpty {
              Text(originalTitle)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .buttonStyle(PlainButtonStyle())
    .contextMenu {
      Button(action: {
        manager.play(collection: collection)
      }) {
        Label("播放", systemImage: "play.fill")
      }

      Button(action: onEdit) {
        Label("编辑系列…", systemImage: "pencil")
      }

      Divider()

      if let firstEp = collection.episodes.first, firstEp.fileExists {
        Button(action: {
          NSWorkspace.shared.selectFile(firstEp.filePath, inFileViewerRootedAtPath: "")
        }) {
          Label("在访达中显示", systemImage: "folder")
        }
      }

      Divider()

      Button(role: .destructive, action: {
        if let catId = manager.selectedCategoryId {
          manager.deleteCollection(collectionId: collection.id, from: catId)
        }
      }) {
        Label("删除系列", systemImage: "trash")
      }
    }
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
      // 默认优雅占位海报
      ZStack {
        LinearGradient(
          colors: [CollectionTheme.darkCardBackground, Color(red: 0.1, green: 0.12, blue: 0.15)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )

        VStack(spacing: 8) {
          Image(systemName: "film")
            .font(.system(size: 32, weight: .light))
            .foregroundColor(.secondary.opacity(0.5))
          Text(collection.title)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .lineLimit(3)
        }
      }
    }
  }

  private func badgeView(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.system(size: 10, weight: .bold))
      .foregroundColor(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(
        BlurView(material: .ultraThin, blendingMode: .withinWindow)
          .overlay(color.opacity(0.6))
      )
      .cornerRadius(CollectionTheme.badgeCornerRadius)
  }
}

// MARK: - Blur View Helper for macOS

struct BlurView: NSViewRepresentable {
  var material: NSVisualEffectView.Material = .hudWindow
  var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
  }
}
