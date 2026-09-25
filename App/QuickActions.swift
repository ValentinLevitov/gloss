import Observation
import SwiftUI
import UIKit

/// Home-screen quick actions (long-press on the app icon).
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()
    static let studyType = "com.vlevitov.translator.study"

    /// Set when the app was opened through a quick action; the UI consumes and clears it.
    var pendingStudy = false

    /// Publishes the "Study words" item with the current count; called whenever the app becomes active.
    func refresh() {
        let count = CardStore.shared.cards.filter { !$0.isLearned }.count
        guard count > 0 else {
            UIApplication.shared.shortcutItems = []
            return
        }
        let subtitle = String(localized: "\(count) words to learn")
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(type: Self.studyType,
                                      localizedTitle: String(localized: "Study words"),
                                      localizedSubtitle: subtitle,
                                      icon: UIApplicationShortcutIcon(systemImageName: "rectangle.stack"),
                                      userInfo: nil),
        ]
    }

    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard item.type == Self.studyType else { return false }
        pendingStudy = true
        return true
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: session.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        if let item = options.shortcutItem { _ = QuickActions.shared.handle(item) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.shared.handle(shortcutItem))
    }
}
