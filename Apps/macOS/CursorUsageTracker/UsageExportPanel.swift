import AppKit
import UniformTypeIdentifiers
import CursorUsageCore

enum UsageExportPanel {
    static func present(snapshot: UsageSnapshot) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.commaSeparatedText, .json]
        panel.nameFieldStringValue = "cursor-usage.csv"
        panel.title = "Export usage"
        panel.message = "CSV or JSON of the numbers this app already shows. No tokens or keys."
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if url.pathExtension.lowercased() == "json" {
                    try UsageExport.json(snapshot).write(to: url, options: .atomic)
                } else {
                    try UsageExport.csv(snapshot).write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "Couldn’t export usage"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }
}
