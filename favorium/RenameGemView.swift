//
//  RenameGemView.swift
//  favorium
//
//  Sheet for a gem's creator to give it a name (rename_coin).
//

import SwiftUI

struct RenameGemView: View {
    let coinId: UUID
    let currentName: String
    let dna: SupabaseService.GemDNA?
    let transferCount: Int
    /// Called with the name as stored by the server
    let onRenamed: (String) -> Void

    @State private var name: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        coinId: UUID,
        currentName: String,
        dna: SupabaseService.GemDNA?,
        transferCount: Int,
        onRenamed: @escaping (String) -> Void
    ) {
        self.coinId = coinId
        self.currentName = currentName
        self.dna = dna
        self.transferCount = transferCount
        self.onRenamed = onRenamed
        // Start blank for starter names so the user writes their own
        _name = State(initialValue: GemNaming.isStarterName(currentName) ? "" : currentName)
    }

    private var cleaned: String { GemNaming.normalized(name) }
    private var canSave: Bool {
        !cleaned.isEmpty && cleaned.count <= GemNaming.maxLength && cleaned != currentName && !isSaving
    }

    var body: some View {
        ZStack {
            FavoriumTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(FavoriumTheme.ivory)
                                .frame(width: 40, height: 40)
                                .background(FavoriumTheme.surface)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Close")
                        Spacer()
                        Text("Name your gem")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(FavoriumTheme.ivory)
                        Spacer()
                        Color.clear.frame(width: 40, height: 40)
                    }
                    .padding(.top, 16)

                    FavorGemView(dna: dna, transferCount: transferCount, size: 150)
                        .frame(height: 170)

                    Text("You created this gem, so its name is yours to give. It travels with the gem through every favor.")
                        .font(FavoriumTheme.captionFont)
                        .foregroundColor(FavoriumTheme.ivoryDim)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .trailing, spacing: 6) {
                        TextField(GemNaming.isStarterName(currentName) ? currentName : "A name with meaning",
                                  text: $name)
                            .font(.system(size: 20, weight: .semibold, design: .serif))
                            .foregroundColor(FavoriumTheme.ivory)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .focused($isFieldFocused)
                            .tint(FavoriumTheme.accent)
                            .onSubmit { if canSave { save() } }
                            .padding(14)
                            .background(FavoriumTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                                    .stroke(FavoriumTheme.accent.opacity(0.35), lineWidth: 1)
                            )

                        Text("\(cleaned.count)/\(GemNaming.maxLength)")
                            .font(.system(size: 11))
                            .foregroundColor(cleaned.count > GemNaming.maxLength ? FavoriumTheme.amber : FavoriumTheme.ivoryDim)
                            .monospacedDigit()
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(FavoriumTheme.captionFont)
                            .foregroundColor(FavoriumTheme.amber)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving {
                                ProgressView().tint(FavoriumTheme.onGold)
                            } else {
                                Image(systemName: "pencil.line")
                            }
                            Text("Save name")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .metallicGoldCapsule()
                        .opacity(canSave ? 1.0 : 0.4)
                    }
                    .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear { isFieldFocused = true }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                let stored = try await SupabaseService.shared.renameCoin(coinId: coinId, name: cleaned)
                onRenamed(stored)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

#Preview("Rename gem") {
    RenameGemView(coinId: UUID(), currentName: "Darkheart Ripple", dna: nil, transferCount: 0) { _ in }
}
