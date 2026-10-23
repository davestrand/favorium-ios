//
//  AccountPauseView.swift
//  favorium
//
//  "Your account is paused" (IOS_CONTRACT §19.5). Built only from when the pause
//  started and when it lifts. The staff note in `my_pause().reason` is never shown:
//  it can name the person who reported and quote them.
//
//  A pause stops engraving, offering a favor and changing your name. Everything
//  else (accepting, confirming, giving gems, reporting, blocking) keeps working,
//  so nothing else in the app is greyed out.
//

import SwiftUI

/// The full notice, for the Profile tab.
struct AccountPauseNotice: View {
    let pause: SupabaseService.AccountPause

    var body: some View {
        // Re-evaluates each minute so the notice hides itself the moment the pause ends
        TimelineView(.everyMinute) { context in
            if pause.isActive(at: context.date) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "pause.circle.fill")
                            .foregroundColor(FavoriumTheme.amber)
                        Text("Your account is paused")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                    }
                    Text("Paused \(AccountPauseCopy.untilPhrase(pause))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(FavoriumTheme.amber)
                    Text("You can\u{2019}t write a new message inside a gem, send a new Favor request, or change your display name \(AccountPauseCopy.untilPhrase(pause)). Everything else still works: accepting, confirming and passing on a gem all stay open, and nothing already in motion is cancelled.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Favorium applied this pause. If you think it\u{2019}s a mistake, write to us and a person will read it.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FavoriumTheme.amber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: FavoriumTheme.cardRadius)
                        .stroke(FavoriumTheme.amber.opacity(0.35), lineWidth: 1)
                )
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// A one-line heads-up on screens whose main action the pause stops.
struct AccountPauseBanner: View {
    let pause: SupabaseService.AccountPause
    /// "send a new Favor request", "write a message inside a gem"
    let blockedAction: String

    var body: some View {
        TimelineView(.everyMinute) { context in
            if pause.isActive(at: context.date) {
                Label {
                    Text("Your account is paused, so you can\u{2019}t \(blockedAction) \(AccountPauseCopy.untilPhrase(pause)).")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "pause.circle.fill")
                }
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.amber)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FavoriumTheme.amber.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
            }
        }
    }
}

enum AccountPauseCopy {
    /// "until Fri 24 Oct, 09:14", or "until it is lifted" for an open-ended pause
    static func untilPhrase(_ pause: SupabaseService.AccountPause) -> String {
        guard let until = pause.until else { return "until it is lifted" }
        let date = until.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let time = until.formatted(.dateTime.hour().minute())
        return "until \(date), \(time)"
    }
}

/// Keeps `AppViewModel.pause` current: on sign-in, on returning to the app, and about
/// once a minute, since staff can pause someone while the app is open.
struct AccountPauseWatcher: ViewModifier {
    let appVM: AppViewModel
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task(id: appVM.userId) {
                guard appVM.userId != nil else { return }
                while !Task.isCancelled {
                    await appVM.refreshPause()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await appVM.refreshPause() } }
            }
    }
}

#Preview("Paused") {
    ScrollView {
        VStack(spacing: 16) {
            AccountPauseNotice(pause: .init(muted_until: "2030-10-24T09:14:00Z", paused_since: "2026-10-17T09:14:00Z"))
            AccountPauseBanner(pause: .init(muted_until: nil, paused_since: "2026-10-17T09:14:00Z"),
                               blockedAction: "send a new Favor request")
        }
        .padding(16)
    }
    .background(FavoriumTheme.background)
}
