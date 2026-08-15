import BackgroundTasks
import AIMeterCore

enum BackgroundRefresh {
    static let identifier = "com.jamesware.aimeter.ios.refresh"

    static func register(store: UsageStore) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            handle(task as! BGAppRefreshTask, store: store)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask, store: UsageStore) {
        schedule()
        let work = Task {
            await store.refresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
