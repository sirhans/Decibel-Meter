//
//  Decibel_MeterApp.swift
//  Decibel Meter
//
//  Created by hans anderson on 6/14/26.
//

import AppKit
import SwiftUI

@main
struct Decibel_MeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createClockPanel()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenParametersDidChange() {
        positionPanel()
    }

    private func createClockPanel() {
        let contentView = NSHostingView(rootView: ContentView())
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.level = .screenSaver
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        self.panel = panel
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func positionPanel() {
        guard let panel else { return }

        let contentSize = panel.contentView?.fittingSize ?? CGSize(width: 240, height: 80)
        let targetSize = CGSize(
            width: max(contentSize.width, 220),
            height: max(contentSize.height, 64)
        )

        if let screen = NSScreen.main {
            let margin: CGFloat = 24
            let frame = NSRect(
                x: screen.visibleFrame.maxX - targetSize.width - margin,
                y: screen.visibleFrame.maxY - targetSize.height - margin,
                width: targetSize.width,
                height: targetSize.height
            )
            panel.setFrame(frame, display: true)
        }
    }
}
