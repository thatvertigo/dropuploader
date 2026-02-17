//
//  ProgressWindowController.swift
//  DropUploader
//
//  Created by Miles on 2/17/26.
//

import AppKit

@MainActor
final class ProgressWindowController: NSWindowController {
    private let titleLabel = NSTextField(labelWithString: "Uploading…")
    private let detailLabel = NSTextField(labelWithString: "")
    private let progress = NSProgressIndicator()

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 520, height: 170)

        let window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Uploading"
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating

        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard let window = window else { return }
        let content = NSView(frame: window.contentView!.bounds)
        content.autoresizingMask = [.width, .height]
        window.contentView = content

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.frame = NSRect(x: 30, y: 120, width: 460, height: 24)

        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingMiddle
        detailLabel.frame = NSRect(x: 30, y: 95, width: 460, height: 18)

        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.doubleValue = 0
        progress.controlSize = .regular
        progress.style = .bar
        progress.frame = NSRect(x: 30, y: 55, width: 360, height: 20)

        content.addSubview(titleLabel)
        content.addSubview(detailLabel)
        content.addSubview(progress)
    }

    func show(fileName: String) {
        titleLabel.stringValue = "Uploading…"
        detailLabel.stringValue = fileName
        progress.doubleValue = 0
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func updateProgress(_ fraction: Double) {
        progress.doubleValue = max(0, min(1, fraction))
    }

    func complete(with text: String) {
        titleLabel.stringValue = "Done"
        detailLabel.stringValue = text
        progress.doubleValue = 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.close()
        }
    }

    func fail(with text: String) {
        titleLabel.stringValue = "Failed"
        detailLabel.stringValue = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            self?.close()
        }
    }
}
