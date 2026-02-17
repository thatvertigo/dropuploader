import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var serverStore: ServerStore
    @EnvironmentObject var uploader: UploadCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @State private var isTargeted: Bool = false
    @State private var isHovering: Bool = false

    private var serverLine: String {
        if let cfg = serverStore.config {
            return "Uploading to \(cfg.RequestURL)"
        } else {
            return "No server configured (File → Import Server…)"
        }
    }

    private var hoverOverlay: Color {
        switch colorScheme {
        case .dark:
            return Color.white.opacity(isHovering ? 0.08 : 0.04)
        default:
            return Color.black.opacity(isHovering ? 0.08 : 0.03)
        }
    }

    private var plusOpacity: Double {
        switch colorScheme {
        case .dark:
            return 0.7
        default:
            return 0.3
        }
    }

    var body: some View {
        ZStack {
            dropArea
        }
        .padding(14)
        .frame(minWidth: 420, minHeight: 320)
    }

    private var dropArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(hoverOverlay) // dim/lighten effect
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isTargeted ? Color.accentColor : Color.gray.opacity(0.35),
                            lineWidth: 3
                        )
                )
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.easeOut(duration: 0.12), value: isTargeted)

            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 72, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(plusOpacity))
                    .animation(.easeOut(duration: 0.12), value: isHovering)

                // No text until a file is added / upload starts
                if !uploader.status.isEmpty {
                    Text(uploader.status)
                        .font(.footnote)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .frame(maxWidth: 420)
                }
            }
            .padding(.horizontal, 24)

            VStack {
                Spacer()
                Text(serverLine)
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { pickFileAndUpload() }
        .onDrop(of: ["public.file-url"], isTargeted: $isTargeted) { providers in
            handleDrop(providers)
            return true
        }
        .onHover { hovering in
            self.isHovering = hovering
        }
    }

    private func pickFileAndUpload() {
        guard serverStore.config != nil else { return }

        let panel = NSOpenPanel()
        panel.title = "Choose a file to upload"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            uploader.uploadFile(url, using: serverStore, presentation: .mainWindow)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.isFileURL else {
                    uploader.status = "Could not read dropped file."
                    return
                }

                uploader.uploadFile(url, using: serverStore, presentation: .mainWindow)
            }
        }
    }
}
