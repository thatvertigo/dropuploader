import Foundation
import AppKit
import SwiftUI

import Foundation
import AppKit
import SwiftUI

@MainActor
final class ServerStore: ObservableObject {
    @Published var config: ShareXServerConfig? = nil

    @AppStorage("server_config_json") private var storedJSON: String = ""

    init() {
        loadFromStorage()
    }

    func loadFromStorage() {
        guard !storedJSON.isEmpty,
              let data = storedJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(ShareXServerConfig.self, from: data) else {
            config = nil
            return
        }
        config = decoded
    }

    func importServerJSON() {
        let panel = NSOpenPanel()
        panel.title = "Import Server JSON"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(ShareXServerConfig.self, from: data)

            storedJSON = String(data: data, encoding: .utf8) ?? ""
            config = decoded
        } catch {
            let alert = NSAlert()
            alert.messageText = "Import failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
    
    func clearServer() {
        storedJSON = ""
        config = nil
    }
}
