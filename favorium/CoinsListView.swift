//
//  CoinsListView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct CoinsListView: View {
    @State private var vm = CoinsViewModel()
    let userId: UUID

    var body: some View {
        VStack {
            Picker("", selection: $vm.selected) {
                Text("My Favors").tag(CoinsViewModel.Tab.myFavors)
                Text("My Originals").tag(CoinsViewModel.Tab.myOriginals)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red)
            }

            if vm.isLoading {
                ProgressView().padding()
            }

            List {
                if vm.selected == .myFavors {
                    ForEach(vm.myFavors) { coin in
                        CoinRowView(coin: coin)
                    }
                } else {
                    ForEach(vm.myOriginals) { coin in
                        CoinRowView(coin: coin)
                    }
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Favorium")
        .task {
            await vm.load(userId: userId)
        }
    }
}

#Preview {
    CoinsListView(userId: UUID())
}
