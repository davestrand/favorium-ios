//
//  PushNotifications.swift
//  favorium
//
//  APNs push notifications. Sending lives on the backend (Supabase Edge Function
//  `notify-favor`, fired by a database webhook and owned by the web project; see
//  its PUSH_CONTRACT.md). The app only registers/unregisters this device's token
//  and never calls notify-favor itself, which would double-send.
//
//  Flow: ask permission at a meaningful moment → iOS hands us a device token →
//  register it with Supabase for the signed-in user → unregister on sign-out.
//

import SwiftUI
import UIKit
import UserNotifications

@Observable
final class PushManager: NSObject {
    static let shared = PushManager()

    /// Where a tapped push should take the user
    enum Route: String { case favors, collection, profile }

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// False until the first settings read, so UI doesn't mistake the default
    /// `.notDetermined` for "never asked" and flash the permission prompt.
    private(set) var hasCheckedAuthorization = false
    /// Set when the user taps a push; ContentView consumes it and switches tabs
    var pendingRoute: Route?
    /// Called when a push arrives while the app is open (wired up by ContentView)
    var onForegroundPush: ((_ title: String, _ body: String?, _ favorId: String?, _ kind: String?) -> Void)?

    private var deviceToken: String?
    private var userId: UUID?
    /// The (token, user) pair last registered with Supabase, to avoid repeat calls
    private var registered: (token: String, userId: UUID)?

    /// Xcode builds talk to the APNs sandbox; TestFlight / App Store builds to production.
    private var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    // MARK: - Permission

    var canAskPermission: Bool { hasCheckedAuthorization && authorizationStatus == .notDetermined }

    @MainActor
    func refreshAuthorizationStatus() async {
        authorizationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        hasCheckedAuthorization = true
    }

    /// Shows the system prompt (once) and registers with APNs if allowed.
    @MainActor
    func requestAuthorization() async {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorizationStatus()
        if granted {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    // MARK: - Session

    /// Call when a user signs in (or the app launches signed in).
    @MainActor
    func signedIn(userId: UUID) async {
        self.userId = userId
        await refreshAuthorizationStatus()
        // Already allowed earlier → refresh the token (it can change between launches)
        if authorizationStatus == .authorized || authorizationStatus == .provisional {
            UIApplication.shared.registerForRemoteNotifications()
        }
        await syncRegistration()
    }

    /// Call BEFORE signing out, while the session can still remove this device's token,
    /// so the next person on this phone doesn't get the previous account's pushes.
    @MainActor
    func signingOut() async {
        if let token = registered?.token {
            try? await SupabaseService.shared.unregisterDevice(token: token)
        }
        registered = nil
        userId = nil
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    // MARK: - Token

    @MainActor
    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await syncRegistration() }
    }

    @MainActor
    private func syncRegistration() async {
        guard let token = deviceToken, let userId else { return }
        if let registered, registered.token == token, registered.userId == userId { return }
        do {
            try await SupabaseService.shared.registerDevice(token: token, environment: environment)
            registered = (token, userId)
        } catch {
            // Retried on next launch / sign-in
        }
    }

    // MARK: - Badge

    /// Keeps the app icon badge equal to the in-app "waiting on you" count.
    func updateBadge(_ count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}

// MARK: - Notification delegate

extension PushManager: UNUserNotificationCenterDelegate {
    // These use the completion-handler forms on purpose. The `async` forms are bridged
    // by Swift on a background cooperative thread, and UIKit then finishes handling the
    // notification (snapshot / state restoration) on that thread, which aborts with
    // "Call must be made on main thread". Calling the completion handler on the main
    // queue keeps UIKit on the main thread.

    /// While the app is open, the in-app banner (Realtime) is the only UI for the event —
    /// no second system banner (per the backend's PUSH_CONTRACT).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        // Read what we need here; the notification object isn't Sendable
        let content = notification.request.content
        let title = content.title
        let body = content.body.isEmpty ? nil : content.body
        let favorId = content.userInfo["favorId"] as? String
        let kind = content.userInfo["kind"] as? String
        DispatchQueue.main.async {
            // Refresh screens + show the in-app banner instead of a system one
            PushManager.shared.onForegroundPush?(title, body, favorId, kind)
            completionHandler([])
        }
    }

    /// Tapping a push opens the matching tab.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        // Read what we need here; the response object isn't Sendable
        let routeName = response.notification.request.content.userInfo["route"] as? String
        DispatchQueue.main.async {
            PushManager.shared.pendingRoute = routeName.flatMap(Route.init(rawValue:)) ?? .favors
            completionHandler()
        }
    }
}

// MARK: - App delegate (device token callbacks)

final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Screens that must not rotate (the inside of a gem, where tilt steers) narrow this while shown.
    static var orientationLock: UIInterfaceOrientationMask = .all

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Must be set before launch finishes so taps that launch the app are delivered
        UNUserNotificationCenter.current().delegate = PushManager.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Common in the simulator; real devices retry on the next launch.
    }
}

// MARK: - Soft permission prompt

/// Explains what Favorium will notify about before the one-time system prompt.
struct PushPermissionCard: View {
    let onEnable: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label("Never miss a kindness", systemImage: "bell.badge")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(FavoriumTheme.ivory)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FavoriumTheme.ivoryDim)
                }
                .accessibilityLabel("Not now")
            }
            Text("Get a notification when someone offers to help you, or sends you a gem. That's it — nothing else.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onEnable) {
                Text("Turn on notifications")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .metallicGoldCapsule()
            }
        }
        .padding(16)
        .background(FavoriumTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                .stroke(FavoriumTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}
