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
    private let meterState = MeterState()
    private var audioInputMeter: AudioInputMeter?
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMeterPanel()
        startAudioInput()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        audioInputMeter?.stop()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func screenParametersDidChange() {
        positionPanel()
    }

    @objc private func systemWillSleep() {
        audioInputMeter?.pauseForSleep()
    }

    @objc private func systemDidWake() {
        audioInputMeter?.restartAfterWake()
    }

    private func startAudioInput() {
        let audioInputMeter = AudioInputMeter(state: meterState)
        self.audioInputMeter = audioInputMeter

        Task {
            await audioInputMeter.start()
        }
    }

    private func createMeterPanel() {
        let contentView = NSHostingView(
            rootView: ContentView(meterState: meterState) {
                NSApp.terminate(nil)
            }
        )
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 234, height: 88),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = true
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

        let contentSize = panel.contentView?.fittingSize ?? CGSize(width: 234, height: 88)
        let targetSize = CGSize(
            width: max(contentSize.width, 234),
            height: max(contentSize.height, 88)
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
