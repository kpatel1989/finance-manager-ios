import Foundation
import UIKit

extension Notification.Name {
    static let portfolioQuickUpdateRequested = Notification.Name("portfolio.quickupdate.requested")
    static let portfolioQuickPlannerRequested = Notification.Name("portfolio.quickplanner.requested")
}

final class PortfolioAppDelegate: NSObject, UIApplicationDelegate {
    private var quickActionAtLaunch: UIApplicationShortcutItem?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        quickActionAtLaunch = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        guard let quickActionAtLaunch else { return }
        _ = handle(shortcutItem: quickActionAtLaunch)
        self.quickActionAtLaunch = nil
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handle(shortcutItem: shortcutItem))
    }

    private func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        switch shortcutItem.type {
        case "com.portfolio.quickupdate":
            NotificationCenter.default.post(name: .portfolioQuickUpdateRequested, object: nil)
            return true
        case "com.portfolio.quickbill":
            NotificationCenter.default.post(name: .portfolioQuickPlannerRequested, object: nil)
            return true
        default:
            return false
        }
    }
}
