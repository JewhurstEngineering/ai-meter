import WidgetKit

enum WidgetReload {
    static func afterWritingSnapshot() {
        WidgetCenter.shared.reloadTimelines(ofKind: "CursorUsageWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "CursorUsageWatchWidget")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
