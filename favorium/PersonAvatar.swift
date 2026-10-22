//
//  PersonAvatar.swift
//  favorium
//
//  A person's thumbnail: their profile photo when they have one, otherwise
//  their initial on a jewel-toned circle. The color is derived from the user's
//  id, so the same person always looks the same on every screen and launch.
//  People with a helper title wear its frame (HelperTitles.swift).
//

import SwiftUI

struct PersonAvatar: View {
    let userId: UUID?
    let name: String?
    /// Profile photo, once profiles carry one. Falls back to initials while loading or on failure.
    var photoURL: URL? = nil
    /// Server `helper_level` (0–5); levels 1+ draw the title's frame around the avatar
    var level: Int? = nil
    var size: CGFloat = 44

    /// Convenience for the `avatar_url` strings the backend returns.
    init(userId: UUID?, name: String?, photo: String?, level: Int? = nil, size: CGFloat = 44) {
        self.init(userId: userId, name: name,
                  photoURL: photo.flatMap { $0.isEmpty ? nil : URL(string: $0) }, level: level, size: size)
    }

    init(userId: UUID?, name: String?, photoURL: URL? = nil, level: Int? = nil, size: CGFloat = 44) {
        self.userId = userId
        self.name = name
        self.photoURL = photoURL
        self.level = level
        self.size = size
    }

    private var title: HelperTitle? { level.flatMap(HelperTitle.init(rawValue:)) }

    var body: some View {
        HelperTitleFrame(title: title, size: size) { portrait }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title.map { "\(name ?? "Someone"), \($0.displayName)" } ?? (name ?? "Someone"))
    }

    private var portrait: some View {
        ZStack {
            initials
            if let photoURL {
                AsyncImage(url: photoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(tint.opacity(0.55), lineWidth: max(1, size / 40)))
    }

    private var initials: some View {
        ZStack {
            Circle().fill(
                LinearGradient(
                    colors: [tint.opacity(0.55), tint.opacity(0.25)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            Text(initial)
                .font(.system(size: size * 0.42, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
        }
    }

    private var initial: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    /// Jewel tones that sit well on the velvet background. Picked by a stable checksum
    /// of the UUID's bytes (`hashValue` changes between launches, so it can't be used).
    private var tint: Color {
        let palette: [Color] = [
            Color(red: 0.93, green: 0.75, blue: 0.35),  // topaz
            Color(red: 0.80, green: 0.36, blue: 0.48),  // garnet rose
            Color(red: 0.38, green: 0.74, blue: 0.58),  // emerald
            Color(red: 0.45, green: 0.58, blue: 0.92),  // sapphire
            Color(red: 0.70, green: 0.52, blue: 0.92),  // amethyst
            Color(red: 0.93, green: 0.55, blue: 0.38),  // fire opal
            Color(red: 0.42, green: 0.78, blue: 0.85),  // aquamarine
        ]
        guard let userId else { return FavoriumTheme.accentMuted }
        let bytes = withUnsafeBytes(of: userId.uuid) { Array($0) }
        let checksum = bytes.reduce(0) { ($0 &* 31 &+ Int($1)) & 0xFFFF }
        return palette[checksum % palette.count]
    }
}

#Preview("Avatars") {
    HStack(spacing: 12) {
        PersonAvatar(userId: UUID(), name: "Jellybean", size: 56)
        PersonAvatar(userId: UUID(), name: "Sam", size: 56)
        PersonAvatar(userId: UUID(), name: "alex", size: 56)
        PersonAvatar(userId: nil, name: nil, size: 56)
        PersonAvatar(userId: UUID(), name: "Robin", level: 2, size: 56)
    }
    .padding()
    .background(FavoriumTheme.background)
}
