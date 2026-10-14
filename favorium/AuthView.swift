//
//  AuthView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct AuthView: View {
    @Environment(AuthViewModel.self) private var vm

    var body: some View {
        @Bindable var vm = vm
        
        VStack(spacing: 16) {
            Picker("Mode", selection: $vm.mode) {
                Text("Sign In").tag(AuthViewModel.Mode.signIn)
                Text("Sign Up").tag(AuthViewModel.Mode.signUp)
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $vm.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            SecureField("Password", text: $vm.password)
                .textContentType(.password)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

            if vm.mode == .signUp {
                TextField("Display name (required)", text: $vm.displayName)
                    .textContentType(.name)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            if let info = vm.infoMessage {
                Text(info)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
            }

            Button(action: {
                Task { await vm.submit() }
            }) {
                if vm.isLoading {
                    ProgressView()
                } else {
                    Text(vm.mode == .signIn ? "Sign In" : "Sign Up")
                        .bold()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading || vm.email.isEmpty || vm.password.isEmpty || (vm.mode == .signUp && vm.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

            if vm.isAuthenticated {
                Text("Signed in!")
                Button("Sign Out") {
                    Task { await vm.signOut() }
                }
            }
        }
        .padding()
        .navigationTitle("Favorium")
    }
}

#Preview {
    @Previewable @State var vm = AuthViewModel()
    AuthView()
        .environment(vm)
}
