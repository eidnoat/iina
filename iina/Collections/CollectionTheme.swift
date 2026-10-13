//
//  CollectionTheme.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import SwiftUI

public enum CollectionTheme {
  /// 海报宽高比 (典型电影海报 2:3)
  public static let posterAspectRatio: CGFloat = 2.0 / 3.0

  /// 剧集截帧卡片宽高比 (典型 16:9)
  public static let episodeAspectRatio: CGFloat = 16.0 / 9.0

  /// 海报卡片圆角
  public static let cardCornerRadius: CGFloat = 12.0

  /// 小型标签/胶囊圆角
  public static let badgeCornerRadius: CGFloat = 6.0

  /// 海报阴影
  public static let cardShadowColor = Color.black.opacity(0.35)
  public static let cardShadowRadius: CGFloat = 8.0
  public static let cardShadowY: CGFloat = 4.0

  /// 背景主色（深邃沉浸式，符合影视流媒体观感）
  public static let darkBackground = Color(red: 0.08, green: 0.09, blue: 0.11)
  public static let darkCardBackground = Color(red: 0.14, green: 0.15, blue: 0.18)

  /// 醒目强调色（类似 Infuse 的温暖高对比度橙红或青色）
  public static let accentColor = Color.orange
  public static let accentGradient = LinearGradient(
    colors: [Color.orange, Color.red.opacity(0.85)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
