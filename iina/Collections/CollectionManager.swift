//
//  CollectionManager.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import Cocoa
import Combine
import AVFoundation

public class CollectionManager: ObservableObject {
  public static let shared = CollectionManager()

  @Published public var categories: [MediaCategory] = []
  @Published public var selectedCategoryId: UUID?

  private let fileManager = FileManager.default
  private let jsonEncoder: JSONEncoder
  private let jsonDecoder: JSONDecoder

  private var baseDirectoryURL: URL {
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let bundleId = Bundle.main.bundleIdentifier ?? "com.colliderli.iina"
    return appSupport.appendingPathComponent(bundleId).appendingPathComponent("Collections")
  }

  private var jsonFileURL: URL {
    baseDirectoryURL.appendingPathComponent("collections.json")
  }

  public var coversDirectoryURL: URL {
    baseDirectoryURL.appendingPathComponent("Covers")
  }

  public var thumbnailsDirectoryURL: URL {
    baseDirectoryURL.appendingPathComponent("Thumbnails")
  }

  public var backdropsDirectoryURL: URL {
    baseDirectoryURL.appendingPathComponent("Backdrops")
  }

  private init() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    self.jsonEncoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    self.jsonDecoder = decoder

    createDirectoriesIfNeeded()
    loadData()
    setupPlaybackObservers()
  }

  // MARK: - Directory & File Setup

  private func createDirectoriesIfNeeded() {
    let dirs = [baseDirectoryURL, coversDirectoryURL, thumbnailsDirectoryURL, backdropsDirectoryURL]
    for dir in dirs {
      if !fileManager.fileExists(atPath: dir.path) {
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
      }
    }
  }

  // MARK: - Persistence

  public func loadData() {
    guard fileManager.fileExists(atPath: jsonFileURL.path) else {
      createDefaultCategories()
      saveData()
      return
    }

    do {
      let data = try Data(contentsOf: jsonFileURL)
      let loaded = try jsonDecoder.decode([MediaCategory].self, from: data)
      self.categories = loaded.sorted { $0.sortOrder < $1.sortOrder }
      if selectedCategoryId == nil, let first = categories.first {
        self.selectedCategoryId = first.id
      }
    } catch {
      NSLog("[CollectionManager] Failed to load collections.json: \(error)")
      createDefaultCategories()
    }
  }

  public func saveData() {
    do {
      let data = try jsonEncoder.encode(categories)
      try data.write(to: jsonFileURL, options: .atomic)
    } catch {
      NSLog("[CollectionManager] Failed to save collections.json: \(error)")
    }
  }

  private func createDefaultCategories() {
    self.categories = [
      MediaCategory(name: "电影", iconName: "film", sortOrder: 0),
      MediaCategory(name: "电视剧", iconName: "tv", sortOrder: 1),
      MediaCategory(name: "动漫", iconName: "sparkles", sortOrder: 2),
      MediaCategory(name: "纪录片", iconName: "video.badge.checkmark", sortOrder: 3)
    ]
    self.selectedCategoryId = categories.first?.id
  }

  // MARK: - Category Operations

  public func addCategory(name: String, iconName: String) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let newCategory = MediaCategory(
      name: trimmed,
      iconName: iconName.isEmpty ? "folder" : iconName,
      sortOrder: categories.count
    )
    categories.append(newCategory)
    selectedCategoryId = newCategory.id
    saveData()
  }

  public func updateCategory(id: UUID, name: String, iconName: String) {
    guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
    categories[index].name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    categories[index].iconName = iconName
    saveData()
  }

  public func deleteCategory(id: UUID) {
    categories.removeAll(where: { $0.id == id })
    if selectedCategoryId == id {
      selectedCategoryId = categories.first?.id
    }
    saveData()
  }

  // MARK: - Collection Operations

  public func addCollection(
    to categoryId: UUID,
    title: String,
    originalTitle: String? = nil,
    year: String? = nil,
    summary: String? = nil,
    coverImage: NSImage? = nil,
    backdropImage: NSImage? = nil,
    episodes: [MediaEpisode] = []
  ) -> MediaCollection? {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else { return nil }
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    var coverFilename: String?
    if let coverImage {
      coverFilename = saveImage(coverImage, to: coversDirectoryURL)
    }

    var backdropFilename: String?
    if let backdropImage {
      backdropFilename = saveImage(backdropImage, to: backdropsDirectoryURL)
    }

    let collection = MediaCollection(
      title: trimmed,
      originalTitle: originalTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
      year: year?.trimmingCharacters(in: .whitespacesAndNewlines),
      summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines),
      coverFilename: coverFilename,
      backdropFilename: backdropFilename,
      episodes: episodes
    )

    categories[catIndex].collections.append(collection)
    saveData()
    return collection
  }

  public func updateCollection(
    collectionId: UUID,
    in categoryId: UUID,
    title: String,
    originalTitle: String?,
    year: String?,
    summary: String?,
    coverImage: NSImage?,
    backdropImage: NSImage?,
    targetCategoryId: UUID? = nil
  ) {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
          let colIndex = categories[catIndex].collections.firstIndex(where: { $0.id == collectionId }) else { return }

    var col = categories[catIndex].collections[colIndex]
    col.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    col.originalTitle = originalTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
    col.year = year?.trimmingCharacters(in: .whitespacesAndNewlines)
    col.summary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
    col.updatedAt = Date()

    if let coverImage {
      col.coverFilename = saveImage(coverImage, to: coversDirectoryURL)
    }

    if let backdropImage {
      col.backdropFilename = saveImage(backdropImage, to: backdropsDirectoryURL)
    }

    if let targetCategoryId, targetCategoryId != categoryId,
       let targetCatIndex = categories.firstIndex(where: { $0.id == targetCategoryId }) {
      categories[catIndex].collections.remove(at: colIndex)
      categories[targetCatIndex].collections.append(col)
    } else {
      categories[catIndex].collections[colIndex] = col
    }

    saveData()
  }

  public func deleteCollection(collectionId: UUID, from categoryId: UUID) {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }) else { return }
    categories[catIndex].collections.removeAll(where: { $0.id == collectionId })
    saveData()
  }

  // MARK: - Episode Operations

  public func addEpisodes(
    to collectionId: UUID,
    in categoryId: UUID,
    filePaths: [String]
  ) {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
          let colIndex = categories[catIndex].collections.firstIndex(where: { $0.id == collectionId }) else { return }

    var currentEpisodes = categories[catIndex].collections[colIndex].episodes
    let currentMaxNumber = currentEpisodes.map(\.episodeNumber).max() ?? 0

    // 自然字母排序
    let sortedPaths = filePaths.sorted {
      $0.localizedStandardCompare($1) == .orderedAscending
    }

    var nextNumber = currentMaxNumber + 1
    for path in sortedPaths {
      // 避免重复加入相同路径
      if currentEpisodes.contains(where: { $0.filePath == path }) {
        continue
      }
      let filename = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
      let cleanedTitle = cleanEpisodeTitle(from: filename, defaultNumber: nextNumber)

      let episode = MediaEpisode(
        episodeNumber: nextNumber,
        title: cleanedTitle,
        filePath: path
      )
      currentEpisodes.append(episode)
      nextNumber += 1
    }

    categories[catIndex].collections[colIndex].episodes = currentEpisodes
    categories[catIndex].collections[colIndex].updatedAt = Date()
    saveData()
  }

  public func updateEpisode(
    episodeId: UUID,
    collectionId: UUID,
    categoryId: UUID,
    title: String,
    episodeNumber: Int
  ) {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
          let colIndex = categories[catIndex].collections.firstIndex(where: { $0.id == collectionId }),
          let epIndex = categories[catIndex].collections[colIndex].episodes.firstIndex(where: { $0.id == episodeId }) else { return }

    categories[catIndex].collections[colIndex].episodes[epIndex].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    categories[catIndex].collections[colIndex].episodes[epIndex].episodeNumber = episodeNumber
    categories[catIndex].collections[colIndex].updatedAt = Date()
    saveData()
  }

  public func removeEpisode(
    episodeId: UUID,
    collectionId: UUID,
    categoryId: UUID
  ) {
    guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
          let colIndex = categories[catIndex].collections.firstIndex(where: { $0.id == collectionId }) else { return }

    categories[catIndex].collections[colIndex].episodes.removeAll(where: { $0.id == episodeId })
    categories[catIndex].collections[colIndex].updatedAt = Date()
    saveData()
  }

  // MARK: - Images & Thumbnails

  public func imageURL(for filename: String?, in directory: URL) -> URL? {
    guard let filename, !filename.isEmpty else { return nil }
    let url = directory.appendingPathComponent(filename)
    guard fileManager.fileExists(atPath: url.path) else { return nil }
    return url
  }

  public func saveImage(_ image: NSImage, to directory: URL) -> String? {
    let filename = UUID().uuidString + ".jpg"
    let fileURL = directory.appendingPathComponent(filename)

    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
      return nil
    }

    do {
      try jpegData.write(to: fileURL, options: .atomic)
      return filename
    } catch {
      NSLog("[CollectionManager] Failed to save image: \(error)")
      return nil
    }
  }

  /// 从本地视频中生成首帧或指定时间的缩略图
  public func generateThumbnail(for videoPath: String, at seconds: Double = 10.0) -> NSImage? {
    let fileURL = URL(fileURLWithPath: videoPath)
    guard fileManager.fileExists(atPath: videoPath) else { return nil }

    let asset = AVAsset(url: fileURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 640, height: 360)

    let time = CMTime(seconds: seconds, preferredTimescale: 600)
    if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
      return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    return nil
  }

  // MARK: - Playback Integration

  /// 唤起 IINA 播放该系列视频，并自动组装播放列表以便连播
  public func play(collection: MediaCollection, startingFrom episode: MediaEpisode? = nil) {
    let episodes = collection.episodes.filter { $0.fileExists }
    guard !episodes.isEmpty else { return }

    let targetEpisode = episode ?? collection.nextEpisodeToPlay ?? episodes.first!
    let targetIndex = episodes.firstIndex(where: { $0.id == targetEpisode.id }) ?? 0

    let urls = episodes.map { URL(fileURLWithPath: $0.filePath) }

    // 主线程调用 IINA 核心播放
    DispatchQueue.main.async {
      // 优先在当前激活的 PlayerCore 中播放，或创建新的 PlayerCore
      let player = PlayerCore.activePlayerCore
      player.openURLs(urls, playlistIndex: targetIndex)
    }
  }

  /// 自动监听播放器进度，同步回写到收藏数据库
  private func setupPlaybackObservers() {
    NotificationCenter.default.addObserver(forName: .iinaHistoryUpdated, object: nil, queue: .main) { [weak self] _ in
      self?.syncWithPlaybackHistory()
    }
  }

  /// 扫描 IINA 的 HistoryController，同步视频播放进度
  private func syncWithPlaybackHistory() {
    let historyEntries = HistoryController.shared.history
    guard !historyEntries.isEmpty else { return }

    var hasChanges = false

    for catIdx in 0..<categories.count {
      for colIdx in 0..<categories[catIdx].collections.count {
        for epIdx in 0..<categories[catIdx].collections[colIdx].episodes.count {
          let filePath = categories[catIdx].collections[colIdx].episodes[epIdx].filePath
          let fileURL = URL(fileURLWithPath: filePath)

          if let match = historyEntries.first(where: { $0.url == fileURL }) {
            let duration = match.duration
            let progress = match.progress

            let ep = categories[catIdx].collections[colIdx].episodes[epIdx]
            let newPlayedTime = duration * progress
            let isFinished = progress >= 0.90 // 播放超过 90% 视为已看

            if abs(ep.lastPlayedTime - newPlayedTime) > 2.0 || ep.isFinished != isFinished || ep.duration != duration {
              categories[catIdx].collections[colIdx].episodes[epIdx].duration = duration
              categories[catIdx].collections[colIdx].episodes[epIdx].lastPlayedTime = newPlayedTime
              categories[catIdx].collections[colIdx].episodes[epIdx].isFinished = isFinished
              hasChanges = true
            }
          }
        }
      }
    }

    if hasChanges {
      saveData()
    }
  }

  // MARK: - Utilities

  /// 智能清洗剧集标题（去掉常见压制参数与杂质）
  private func cleanEpisodeTitle(from raw: String, defaultNumber: Int) -> String {
    var name = raw
    // 去掉常见后缀
    let patterns = [
      "\\[[^\\]]+\\]", "\\([^\\)]+\\)",
      "1080p", "720p", "2160p", "4k", "bluray", "web-dl", "x264", "x265", "hevc", "aac", "dts"
    ]
    for pattern in patterns {
      if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
        name = regex.stringByReplacingMatches(in: name, range: NSRange(location: 0, length: name.utf16.count), withTemplate: " ")
      }
    }
    let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.isEmpty {
      return "第 \(defaultNumber) 集"
    }
    return cleaned
  }

  /// 递归扫描目录下的所有有效视频格式文件
  public func scanPlayableFilesInDirectory(_ dirURL: URL) -> [String] {
    let videoExtensions: Set<String> = [
      "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts", "iso", "rmvb", "vob"
    ]
    var results: [String] = []

    guard let enumerator = fileManager.enumerator(at: dirURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
      return []
    }

    for case let fileURL as URL in enumerator {
      if videoExtensions.contains(fileURL.pathExtension.lowercased()) {
        results.append(fileURL.path)
      }
    }

    return results.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }
}
