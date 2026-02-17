import SwiftUI

@main
struct DropUploaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var serverStore = ServerStore()
    @StateObject private var uploader = UploadCoordinator()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(serverStore)
                .environmentObject(uploader)
                .onAppear {
                    appDelegate.onOpenFiles = { urls in
                        for url in urls where url.isFileURL {
                            uploader.uploadFile(url, using: serverStore, presentation: .progressWindow)
                        }
                    }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Server…") {
                    serverStore.importServerJSON()
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])
                Button("Clear Server") { serverStore.clearServer() }

            }
        }
    }
}
