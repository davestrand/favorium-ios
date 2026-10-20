//
//  AuthView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//
//  Sign in / sign up, dressed in the art-deco "Sovereign" look: gem and
//  marquee title under the sunburst, gold-rimmed navy fields, polished-gold CTA.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var vm

    private enum Field { case email, password, displayName }
    @FocusState private var focused: Field?

    var body: some View {
        @Bindable var vm = vm

        ZStack {
            DecoBackdrop()

            ScrollView {
                VStack(spacing: 28) {
                    header
                        .padding(.top, 56)

                    modeSwitcher

                    VStack(spacing: 14) {
                        DecoTextField(
                            title: "Email",
                            systemImage: "envelope",
                            text: $vm.email,
                            isFocused: focused == .email
                        )
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .email)

                        DecoTextField(
                            title: "Password",
                            systemImage: "lock",
                            text: $vm.password,
                            isSecure: true,
                            isFocused: focused == .password
                        )
                        .textContentType(vm.mode == .signIn ? .password : .newPassword)
                        .focused($focused, equals: .password)

                        if vm.mode == .signUp {
                            DecoTextField(
                                title: "Display name (required)",
                                systemImage: "person",
                                text: $vm.displayName,
                                isFocused: focused == .displayName
                            )
                            .textContentType(.name)
                            .focused($focused, equals: .displayName)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }

                    messages

                    submitButton

                    if vm.isAuthenticated {
                        VStack(spacing: 8) {
                            Text("Signed in!")
                                .foregroundColor(FavoriumTheme.ivory)
                            Button("Sign Out") {
                                Task { await vm.signOut() }
                            }
                            .foregroundColor(FavoriumTheme.accent)
                        }
                        .font(FavoriumTheme.captionFont)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeInOut(duration: 0.25), value: vm.mode)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            FavorGemView(
                gemFamily: .lightning,
                tier: .legacy,
                gemColor: FavoriumTheme.accent,
                size: 96,
                showGlow: true
            )
            .accessibilityHidden(true)

            Text("Favorium")
                .font(FavoriumTheme.titleFont)
                .foregroundColor(FavoriumTheme.ivory)
                .decoTitle()
                .shadow(color: FavoriumTheme.sapphire.opacity(0.6), radius: 12)
                .accessibilityAddTraits(.isHeader)
            DecoDivider()
            Text("Kindness in motion.")
                .font(FavoriumTheme.captionFont)
                .foregroundColor(FavoriumTheme.ivoryDim)
        }
    }

    // MARK: - Sign In / Sign Up switcher

    /// Two tracked-caps tabs with a gold underline on the active one.
    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            modeTab("Sign In", mode: .signIn)
            modeTab("Sign Up", mode: .signUp)
        }
    }

    private func modeTab(_ title: String, mode: AuthViewModel.Mode) -> some View {
        let isSelected = vm.mode == mode
        return Button {
            vm.mode = mode
        } label: {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .medium).width(.expanded))
                    .textCase(.uppercase)
                    .tracking(3)
                    .foregroundColor(isSelected ? FavoriumTheme.accent : FavoriumTheme.ivoryDim)
                Rectangle()
                    .fill(isSelected ? AnyShapeStyle(FavoriumTheme.goldGradient) : AnyShapeStyle(FavoriumTheme.accentMuted.opacity(0.25)))
                    .frame(height: isSelected ? 2 : 1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Messages

    @ViewBuilder
    private var messages: some View {
        if let info = vm.infoMessage {
            Text(info)
                .font(.footnote)
                .foregroundColor(FavoriumTheme.ivoryDim)
                .multilineTextAlignment(.center)
        }
        if let error = vm.errorMessage {
            Text(error)
                .font(.footnote)
                .foregroundColor(Color(red: 1.0, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Submit

    private var isSubmitDisabled: Bool {
        vm.isLoading || vm.email.isEmpty || vm.password.isEmpty ||
        (vm.mode == .signUp && vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var submitButton: some View {
        Button {
            focused = nil
            Task { await vm.submit() }
        } label: {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .tint(FavoriumTheme.onGold)
                } else {
                    Text(vm.mode == .signIn ? "Sign In" : "Sign Up")
                        .font(.system(size: 15, weight: .semibold).width(.expanded))
                        .textCase(.uppercase)
                        .tracking(3)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .metallicGoldCapsule()
        }
        .buttonStyle(.plain)
        .disabled(isSubmitDisabled)
        .opacity(isSubmitDisabled && !vm.isLoading ? 0.5 : 1)
    }
}

// MARK: - Deco text field

/// Navy field with a leading glyph and a gold hairline rim that brightens on focus.
private struct DecoTextField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var isSecure = false
    var isFocused = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(isFocused ? FavoriumTheme.accent : FavoriumTheme.accentMuted)
                .frame(width: 20)
                .accessibilityHidden(true)

            let prompt = Text(title).foregroundColor(FavoriumTheme.ivoryDim.opacity(0.6))
            Group {
                if isSecure {
                    SecureField(title, text: $text, prompt: prompt)
                } else {
                    TextField(title, text: $text, prompt: prompt)
                }
            }
            .font(FavoriumTheme.bodyFont)
            .foregroundColor(FavoriumTheme.ivory)
            .tint(FavoriumTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(FavoriumTheme.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FavoriumTheme.rowRadius)
                .strokeBorder(
                    isFocused ? FavoriumTheme.accent.opacity(0.8) : FavoriumTheme.accentMuted.opacity(0.35),
                    lineWidth: 1
                )
        )
        .shadow(color: isFocused ? FavoriumTheme.sapphire.opacity(0.35) : .clear, radius: 10)
        .animation(.easeOut(duration: 0.2), value: isFocused)
    }
}

#Preview {
    @Previewable @State var vm = AuthViewModel()
    NavigationStack {
        AuthView()
    }
    .environment(vm)
}
