//
//  AppDelegate.swift
//  DropUploader
//
//  Created by Miles on 2/17/26.
//

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    static var openedExternally = false

    var onOpenFiles: (([URL]) -> Void)?

    func application(_ application: NSApplication, open urls: [URL]) {
        Self.openedExternally = true
        onOpenFiles?(urls)
        hideAllRegularWindows()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if Self.openedExternally {
            hideAllRegularWindows()
        }
    }

    private func hideAllRegularWindows() {
        for w in NSApp.windows {
            if w.isVisible, w.level == .normal {
                w.orderOut(nil)
            }
        }

        NSApp.deactivate()
    }
}
