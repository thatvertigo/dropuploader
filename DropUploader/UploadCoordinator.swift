// UploadCoordinator.swift
import Foundation
import AppKit
import SwiftUI

@MainActor
final class UploadCoordinator: ObservableObject {
    enum Presentation {
        case mainWindow
        case progressWindow
    }

    @Published var status: String = ""

    private var progressWC: ProgressWindowController?
    private var currentTask: URLSessionUploadTask?

    func uploadFile(_ fileURL: URL, using store: ServerStore, presentation: Presentation) {
        guard let cfg = store.config else { return }

        currentTask?.cancel()
        currentTask = nil

        let uploader = Uploader(config: cfg)

        switch presentation {
        case .progressWindow:
            if progressWC == nil { progressWC = ProgressWindowController() }
            progressWC?.show(fileName: fileURL.lastPathComponent)

        case .mainWindow:
            status = "Uploading…"
        }

        Task {
            do {
                let uploadedURL = try await uploader.upload(
                    fileURL: fileURL,
                    onProgress: { [weak self] fraction in
                        Task { @MainActor in
                            guard let self else { return }
                            if presentation == .progressWindow {
                                self.progressWC?.updateProgress(fraction)
                            }
                        }
                    },
                    onTaskCreated: { [weak self] task in
                        Task { @MainActor in
                            self?.currentTask = task
                        }
                    }
                )

                copyToClipboard(uploadedURL.absoluteString)

                currentTask = nil

                switch presentation {
                case .progressWindow:
                    progressWC?.complete(with: uploadedURL.absoluteString)
                case .mainWindow:
                    status = uploadedURL.absoluteString
                }

            } catch {
                currentTask = nil

                let ns = error as NSError
                let canceled = (ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled)

                let reason: String = {
                    if canceled { return "Canceled" }

                    if ns.domain == NSURLErrorDomain {
                        return "\(ns.localizedDescription) (code \(ns.code))"
                    }

                    return ns.localizedDescription
                }()

                switch presentation {
                case .progressWindow:
                    // keep the progress window simple but informative
                    progressWC?.fail(with: reason)

                case .mainWindow:
                    // THIS is what shows under the plus in gray text
                    status = reason
                }
            }
        }
    }
}

@MainActor
func copyToClipboard(_ string: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(string, forType: .string)
}
