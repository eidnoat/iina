//
//  CollectionMainView.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI
import Cocoa

public struct CollectionMainView: View {
  @StateObject private var manager = CollectionManager.shared

  @State private var searchText: String = ""
  @State private var activeDetailCollection: MediaCollection?

  @State private var showEditCollectionSheet = false
  @State private var editingCollection: MediaCollection?

  @State private var showEditCategorySheet = false
  @State private var editingCategory: MediaCategory?

  public init() {}

  public var body: some View {
    NavigationView {
      // 左侧分类侧边栏
      sidebarView
        .frame(minWidth: 200, idealWidth: 220, maxWidth: 280)

      // 右侧主内容区域
      mainContentView
        .frame(minWidth: 600)
    }
    .background(CollectionTheme.darkBackground)
    .sheet(isPresented: $showEditCollectionSheet) {
      if let currentCatId = manager.selectedCategoryId {
        EditCollectionSheet(
          manager: manager,
          currentCategoryId: currentCatId,
          editingCollection: editingCollection,
          onDismiss: {
            showEditCollectionSheet = false
            editingCollection = nil
            // 刷新当前详情页
            if let active = activeDetailCollection,
               let updatedCat = manager.categories.first(where: { $0.id == currentCatId }),
               let updatedCol = updatedCat.collections.first(where: { $0.id == active.id }) {
              activeDetailCollection = updatedCol
            }
          }
        )
      }
    }
    .sheet(isPresented: $showEditCategorySheet) {
      EditCategorySheet(
        manager: manager,
        editingCategory: editingCategory,
        onDismiss: {
          showEditCategorySheet = false
          editingCategory = nil
        }
      )
    }
  }

  // MARK: - Sidebar View

  private var sidebarView: some View {
    VStack(spacing: 0) {
      // 侧边栏标题
      HStack(spacing: 8) {
        Image(systemName: "film.fill")
          .font(.system(size: 16))
          .foregroundColor(CollectionTheme.accentColor)
        Text("影视收藏中心")
          .font(.system(size: 14, weight: .bold))
          .foregroundColor(.white)
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)

      Divider()

      // 分类列表
      List(selection: $manager.selectedCategoryId) {
        Section(header: Text("媒体分类").font(.system(size: 11)).foregroundColor(.secondary)) {
          ForEach(manager.categories) { category in
            NavigationLink(
              destination: EmptyView(),
              tag: category.id,
              selection: $manager.selectedCategoryId
            ) {
              HStack(spacing: 10) {
                Image(systemName: category.iconName)
                  .font(.system(size: 14))
                  .foregroundColor(manager.selectedCategoryId == category.id ? CollectionTheme.accentColor : .secondary)
                  .frame(width: 20)

                Text(category.name)
                  .font(.system(size: 13, weight: .medium))
                  .foregroundColor(.primary)

                Spacer()

                Text("\(category.collections.count)")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Color.white.opacity(0.08))
                  .cornerRadius(10)
              }
              .padding(.vertical, 2)
            }
            .contextMenu {
              Button(action: {
                editingCategory = category
                showEditCategorySheet = true
              }) {
                Label("编辑分类…", systemImage: "pencil")
              }

              if manager.categories.count > 1 {
                Button(role: .destructive, action: {
                  manager.deleteCategory(id: category.id)
                }) {
                  Label("删除分类", systemImage: "trash")
                }
              }
            }
          }
        }
      }
      .listStyle(SidebarListStyle())

      Divider()

      // 侧边栏底部新建分类按钮
      Button(action: {
        editingCategory = nil
        showEditCategorySheet = true
      }) {
        HStack(spacing: 6) {
          Image(systemName: "plus.circle")
          Text("新建分类")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .background(BlurView(material: .sidebar, blendingMode: .behindWindow))
  }

  // MARK: - Main Content View

  private var mainContentView: some View {
    VStack(spacing: 0) {
      // 顶栏搜索与操作
      mainHeaderBar

      Divider()

      // 主体内容（根据是否进入详情页切换）
      if let activeCol = activeDetailCollection, let currentCat = selectedCategory {
        CollectionDetailView(
          collection: activeCol,
          category: currentCat,
          manager: manager,
          onBack: {
            activeDetailCollection = nil
          },
          onEdit: {
            editingCollection = activeCol
            showEditCollectionSheet = true
          }
        )
      } else if let currentCat = selectedCategory {
        PosterGridView(
          manager: manager,
          category: currentCat,
          searchText: searchText,
          onSelectCollection: { col in
            activeDetailCollection = col
          },
          onEditCollection: { col in
            editingCollection = col
            showEditCollectionSheet = true
          }
        )
      } else {
        VStack {
          Spacer()
          Text("请从左侧选择一个分类")
            .foregroundColor(.secondary)
          Spacer()
        }
      }
    }
    .background(CollectionTheme.darkBackground)
  }

  private var selectedCategory: MediaCategory? {
    manager.categories.first(where: { $0.id == manager.selectedCategoryId })
  }

  // MARK: - Header Bar

  private var mainHeaderBar: some View {
    HStack(spacing: 16) {
      if let currentCat = selectedCategory {
        HStack(spacing: 8) {
          Image(systemName: currentCat.iconName)
            .foregroundColor(CollectionTheme.accentColor)
          Text(currentCat.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
        }
      }

      Spacer()

      // 搜索框
      HStack(spacing: 6) {
        Image(systemName: "magnifyingglass")
          .foregroundColor(.secondary)
        TextField("搜索影视系列或剧集…", text: $searchText)
          .textFieldStyle(PlainTextFieldStyle())
          .font(.system(size: 12))
        if !searchText.isEmpty {
          Button(action: { searchText = "" }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.white.opacity(0.08))
      .cornerRadius(8)
      .frame(width: 220)

      // 新建系列按钮
      Button(action: {
        editingCollection = nil
        showEditCollectionSheet = true
      }) {
        HStack(spacing: 6) {
          Image(systemName: "plus")
          Text("新建系列")
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(CollectionTheme.accentGradient)
        .cornerRadius(8)
        .shadow(color: CollectionTheme.accentColor.opacity(0.3), radius: 4, y: 2)
      }
      .buttonStyle(PlainButtonStyle())
      .disabled(selectedCategory == nil)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 12)
  }
}
