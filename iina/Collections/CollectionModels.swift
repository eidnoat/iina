//
//  CollectionModels.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import Foundation
import SwiftUI

/// 一级分类（例如：电影、电视剧、动漫、纪录片）
public struct MediaCategory: Identifiable, Codable, Equatable, Hashable {
  public var id: UUID
  public var name: String
  public var iconName: String
  public var sortOrder: Int
  public var collections: [MediaCollection]

  public init(
    id: UUID = UUID(),
    name: String,
    iconName: String = "folder",
    sortOrder: Int = 0,
    collections: [MediaCollection] = []
  ) {
    self.id = id
    self.name = name
    self.iconName = iconName
    self.sortOrder = sortOrder
    self.collections = collections
  }

  public var totalItemsCount: Int {
    collections.count
  }

  public var totalEpisodesCount: Int {
    collections.reduce(0) { $0 + $1.episodes.count }
  }
}

/// 二级系列（例如：《绝命毒师》、《指环王三部曲》）
public struct MediaCollection: Identifiable, Codable, Equatable, Hashable {
  public var id: UUID
  public var title: String
  public var originalTitle: String?
  public var year: String?
  public var summary: String?
  /// 存储在 Collections/Covers 目录下的相对文件名
  public var coverFilename: String?
  /// 存储在 Collections/Backdrops 目录下的横幅背景相对文件名
  public var backdropFilename: String?
  public var episodes: [MediaEpisode]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    title: String,
    originalTitle: String? = nil,
    year: String? = nil,
    summary: String? = nil,
    coverFilename: String? = nil,
    backdropFilename: String? = nil,
    episodes: [MediaEpisode] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.originalTitle = originalTitle
    self.year = year
    self.summary = summary
    self.coverFilename = coverFilename
    self.backdropFilename = backdropFilename
    self.episodes = episodes
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// 计算整个系列的整体观看进度 (0.0 ~ 1.0)
  public var overallProgress: Double {
    guard !episodes.isEmpty else { return 0.0 }
    let totalPlayed = episodes.reduce(0.0) { sum, ep in
      if ep.isFinished {
        return sum + (ep.duration > 0 ? ep.duration : 1.0)
      } else {
        return sum + ep.lastPlayedTime
      }
    }
    let totalDuration = episodes.reduce(0.0) { sum, ep in
      sum + (ep.duration > 0 ? ep.duration : 1.0)
    }
    guard totalDuration > 0 else { return 0.0 }
    return min(1.0, max(0.0, totalPlayed / totalDuration))
  }

  /// 未观看的剧集数量
  public var unwatchedCount: Int {
    episodes.filter { !$0.isFinished && $0.lastPlayedTime < 5.0 }.count
  }

  /// 是否全部看完
  public var isAllFinished: Bool {
    !episodes.isEmpty && episodes.allSatisfy { $0.isFinished }
  }

  /// 获取下一集应当播放的 Episode（优先未播放或正在播放中）
  public var nextEpisodeToPlay: MediaEpisode? {
    // 1. 优先找播放中但未完成的
    if let inProgress = episodes.first(where: { !$0.isFinished && $0.lastPlayedTime > 5.0 }) {
      return inProgress
    }
    // 2. 找第一个未完成的
    if let firstUnfinished = episodes.first(where: { !$0.isFinished }) {
      return firstUnfinished
    }
    // 3. 默认第一集
    return episodes.first
  }
}

/// 系列下的具体视频（例如：第 1 集、某部特定电影）
public struct MediaEpisode: Identifiable, Codable, Equatable, Hashable {
  public var id: UUID
  public var episodeNumber: Int
  public var title: String
  public var filePath: String
  public var duration: Double
  public var lastPlayedTime: Double
  public var isFinished: Bool
  public var thumbnailFilename: String?
  public var addedAt: Date

  public init(
    id: UUID = UUID(),
    episodeNumber: Int = 1,
    title: String,
    filePath: String,
    duration: Double = 0.0,
    lastPlayedTime: Double = 0.0,
    isFinished: Bool = false,
    thumbnailFilename: String? = nil,
    addedAt: Date = Date()
  ) {
    self.id = id
    self.episodeNumber = episodeNumber
    self.title = title
    self.filePath = filePath
    self.duration = duration
    self.lastPlayedTime = lastPlayedTime
    self.isFinished = isFinished
    self.thumbnailFilename = thumbnailFilename
    self.addedAt = addedAt
  }

  /// 单集播放进度比例 (0.0 ~ 1.0)
  public var progressRatio: Double {
    guard duration > 0 else { return 0.0 }
    if isFinished { return 1.0 }
    return min(1.0, max(0.0, lastPlayedTime / duration))
  }

  /// 格式化时长（例如：45:20 或 01:25:30）
  public var formattedDuration: String {
    guard duration > 0 else { return "--:--" }
    return formatTimeInterval(duration)
  }

  /// 格式化播放进度（例如：已播 15:20 / 45:20）
  public var formattedProgress: String {
    guard duration > 0 else { return "" }
    if isFinished {
      return "已看完"
    } else if lastPlayedTime > 0 {
      return "已播 " + formatTimeInterval(lastPlayedTime)
    } else {
      return "未播放"
    }
  }

  /// 文件是否存在
  public var fileExists: Bool {
    FileManager.default.fileExists(atPath: filePath)
  }

  private func formatTimeInterval(_ interval: Double) -> String {
    let totalSeconds = Int(interval)
    let hours = totalSeconds / 3600
    let minutes = (totalSeconds % 3600) / 60
    let seconds = totalSeconds % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    } else {
      return String(format: "%02d:%02d", minutes, seconds)
    }
  }
}
