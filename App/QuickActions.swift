import Observation
import SwiftUI
import UIKit

/// Home-screen quick actions (long-press on the app icon).
@MainActor
@Observable
final class QuickActions {
    static let shared = QuickActions()
    static let studyType = "com.vlevitov.translator.study"
    static let cameraType = "com.vlevitov.translator.camera"
    static let cameraURL = URL(string: "gloss://camera")!

    /// Set when the app was opened through a quick action or URL; the UI consumes and clears them.
    var pendingStudy = false
    var pendingCamera = false

    /// Publishes the "Study words" item with the current count; called whenever the app becomes active.
    func refresh() {
        var items = [
            UIApplicationShortcutItem(type: Self.cameraType,
                                      localizedTitle: String(localized: "Translate with camera"),
                                      localizedSubtitle: nil,
                                      icon: UIApplicationShortcutIcon(systemImageName: "camera"),
                                      userInfo: nil),
        ]
        let count = CardStore.shared.cards.filter { !$0.isLearned }.count
        if count > 0 {
            items.append(UIApplicationShortcutItem(type: Self.studyType,
                                                   localizedTitle: String(localized: "Study words"),
                                                   localizedSubtitle: String(localized: "\(count) words to learn"),
                                                   icon: UIApplicationShortcutIcon(systemImageName: "rectangle.stack"),
                                                   userInfo: nil))
        }
        UIApplication.shared.shortcutItems = items
    }

    func handle(_ item: UIApplicationShortcutItem) -> Bool {
        switch item.type {
        case Self.studyType: pendingStudy = true
        case Self.cameraType: pendingCamera = true
        default: return false
        }
        return true
    }

    /// `gloss://camera` from the lock-screen widget (or anywhere else).
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "gloss" else { return false }
        switch url.host {
        case "camera": pendingCamera = true
        case "study": pendingStudy = true
        default: return false
        }
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
        for context in options.urlContexts { _ = QuickActions.shared.handle(context.url) }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts { _ = QuickActions.shared.handle(context.url) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.shared.handle(shortcutItem))
    }
}
