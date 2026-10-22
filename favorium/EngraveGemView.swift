//
//  EngraveGemView.swift
//  favorium
//
//  Engrave a short, unsigned secret inside a gem you hold (IOS_CONTRACT §17).
//  A gem holds at most one engraving; engraving again replaces it for good.
//  The server enforces who may engrave, the daily cooldown, length and the
//  filter, and its error texts are shown verbatim.
//

import SwiftUI

struct EngraveGemView: View {
    let coinId: UUID
    let gemName: String
    let dna: SupabaseService.GemDNA?
    let transferCount: Int
    /// The gem already holds words, so these will replace them
    let isReplacing: Bool
    var onEngraved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var maxLength: Int?
    @State private var isSaving = false
    @State private var error: String?
    @State private var done = false
    @FocusState private var focused: Bool

    /// Mirrors the server's normalising: trimmed, runs of whitespace collapsed
    private var normalized: String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    /// The server counts characters (code points), not visible glyphs
    private var length: Int { normalized.unicodeScalars.count }
    private var tooLong: Bool { maxLength.map { length > $0 } ?? false }
    private var canSave: Bool { length > 0 && !tooLong && !isSaving }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()
            if done { doneView } else { form }
        }
        .task {
            maxLength = try? await SupabaseService.shared.engravingSettings().max_length
            focused = true
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 22) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(FavoriumTheme.ivoryDim)
                    Spacer()
                }
                .padding(.top, 16)

                FavorGemView(dna: dna, transferCount: transferCount, size: 110)

                VStack(spacing: 6) {
                    Text(isReplacing ? "Replace the secret" : "Engrave a secret")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                    Text("A few words sealed inside \(gemName). They're unsigned, and only whoever holds the gem can find them.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isReplacing {
                    Label {
                        Text("This gem already holds a secret. Your words will replace it forever.")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(FavoriumTheme.captionFont)
                    .foregroundColor(FavoriumTheme.amber)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FavoriumTheme.amber.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                }

                VStack(alignment: .trailing, spacing: 6) {
                    TextField("You've got this!", text: $text, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 18, design: .serif))
                        .foregroundColor(FavoriumTheme.ivory)
                        .focused($focused)
                        .padding(14)
                        .background(FavoriumTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                        .overlay(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                            .stroke(tooLong ? FavoriumTheme.amber : FavoriumTheme.accentMuted.opacity(0.4), lineWidth: 1))
                    if let maxLength {
                        Text("\(length)/\(maxLength)")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundColor(tooLong ? FavoriumTheme.amber : FavoriumTheme.ivoryDim)
                    }
                }

                if let error {
                    Text(error)
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.amber)
                        .multilineTextAlignment(.center)
                }

                Button(action: save) {
                    HStack {
                        if isSaving { ProgressView().tint(FavoriumTheme.onGold) } else { Image(systemName: "seal.fill") }
                        Text(isReplacing ? "Replace" : "Engrave").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
                    .opacity(canSave ? 1 : 0.4)
                }
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private var doneView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "seal.fill")
                .font(.system(size: 54))
                .foregroundColor(FavoriumTheme.accent)
            Text("Sealed inside \(gemName)")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(FavoriumTheme.ivory)
                .multilineTextAlignment(.center)
            Text("Whoever holds it next can find your words by stepping inside and being still.")
                .font(FavoriumTheme.bodyFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Spacer()
            Button {
                onEngraved()
                dismiss()
            } label: {
                Text("Done").fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .metallicGoldCapsule()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        error = nil
        Task {
            do {
                _ = try await SupabaseService.shared.engraveCoin(coinId: coinId, text: normalized)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.3)) { done = true }
            } catch {
                // The server's messages are written to be shown as they are
                self.error = SupabaseService.errorMessage(error)
            }
            isSaving = false
        }
    }
}

#Preview("Engrave") {
    EngraveGemView(coinId: UUID(), gemName: "Black Heart", dna: nil, transferCount: 8, isReplacing: true)
}
