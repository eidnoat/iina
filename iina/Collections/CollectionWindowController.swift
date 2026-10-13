//
//  CollectionWindowController.swift
//  iina
//
//  Created for IINA Media Collections.
//  Copyright © 2026 lhc. All rights reserved.
//

import Cocoa
import SwiftUI

public class CollectionWindowController: NSWindowController {
  public static let shared = CollectionWindowController()

  public init() {
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 1060, height: 720),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "影视收藏中心"
    window.minSize = NSSize(width: 860, height: 560)
    window.setFrameAutosaveName("IINACollectionWindow")
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.isReleasedWhenClosed = false

    let hostingView = NSHostingView(rootView: CollectionMainView())
    window.contentView = hostingView

    super.init(window: window)
  }

  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func show() {
    guard let window else { return }
    if !window.isVisible {
      window.center()
    }
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  public func toggle() {
    guard let window else { return }
    if window.isVisible {
      window.orderOut(nil)
    } else {
      show()
    }
  }
}
