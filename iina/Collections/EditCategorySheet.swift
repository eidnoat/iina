//
//  EditCategorySheet.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI

public struct EditCategorySheet: View {
  @ObservedObject var manager: CollectionManager
  let editingCategory: MediaCategory?
  let onDismiss: () -> Void

  @State private var name: String = ""
  @State private var selectedIcon: String = "film"

  private let availableIcons = [
    "film", "tv", "sparkles", "video.badge.checkmark",
    "popcorn", "theatermasks", "play.tv", "books.vertical",
    "music.note.tv", "star", "heart", "folder"
  ]

  public init(
    manager: CollectionManager,
    editingCategory: MediaCategory? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.manager = manager
    self.editingCategory = editingCategory
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(spacing: 0) {
      // 头部
      HStack {
        Text(editingCategory == nil ? "新建视频分类" : "编辑分类")
          .font(.system(size: 15, weight: .bold))
          .foregroundColor(.white)
        Spacer()
        Button("取消") {
          onDismiss()
        }
        .keyboardShortcut(.cancelAction)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)

      Divider()

      VStack(alignment: .leading, spacing: 18) {
        // 分类名称
        VStack(alignment: .leading, spacing: 6) {
          Text("分类名称 *")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
          TextField("例如：电影、动漫、短剧", text: $name)
            .textFieldStyle(RoundedBorderTextFieldStyle())
        }

        // 图标选择
        VStack(alignment: .leading, spacing: 8) {
          Text("分类图标")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)

          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(availableIcons, id: \.self) { icon in
              Button(action: {
                selectedIcon = icon
              }) {
                ZStack {
                  RoundedRectangle(cornerRadius: 8)
                    .fill(selectedIcon == icon ? CollectionTheme.accentColor.opacity(0.25) : Color.white.opacity(0.05))
                    .overlay(
                      RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedIcon == icon ? CollectionTheme.accentColor : Color.clear, lineWidth: 1.5)
                    )
                  Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(selectedIcon == icon ? CollectionTheme.accentColor : .primary)
                }
                .frame(height: 44)
              }
              .buttonStyle(PlainButtonStyle())
            }
          }
        }
      }
      .padding(20)

      Divider()

      // 底部操作
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
        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
    }
    .frame(width: 380, height: 320)
    .background(CollectionTheme.darkBackground)
    .onAppear {
      if let editing = editingCategory {
        name = editing.name
        selectedIcon = editing.iconName
      }
    }
  }

  private func saveAction() {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }

    if let editing = editingCategory {
      manager.updateCategory(id: editing.id, name: trimmed, iconName: selectedIcon)
    } else {
      manager.addCategory(name: trimmed, iconName: selectedIcon)
    }
    onDismiss()
  }
}
