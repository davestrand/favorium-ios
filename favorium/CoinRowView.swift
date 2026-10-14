//
//  CoinRowView.swift
//  favorium
//
//  Created by Assistant on 10/5/26.
//

import SwiftUI

struct CoinRowView: View {
    let coin: SupabaseService.CoinSummary

    var body: some View {
        NavigationLink(destination: CoinDetailView(coinId: coin.id)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coin.name ?? "Unnamed Favor")
                        .font(.headline)
                    Text(coin.serial ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 12) {
                    if let count = coin.transfer_count {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                            Text("\(count)")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CoinRowView(coin: .init(id: UUID(), serial: "FV-1234", name: "Amber Hearth", transfer_count: 3, creator_id: nil, owner_id: nil, created_at: nil))
}
