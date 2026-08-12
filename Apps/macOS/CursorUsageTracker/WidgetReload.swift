import WidgetKit
import CursorUsageCore

enum WidgetReload {
    static func afterWritingSnapshot() {
        WidgetCenter.shared.reloadTimelines(ofKind: "CursorUsageWidget")
    }
}
