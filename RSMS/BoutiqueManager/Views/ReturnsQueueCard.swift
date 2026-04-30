// PATH: RSMS/BoutiqueManager/Views/ReturnsQueueCard.swift

import SwiftUI

struct ReturnsQueueCard: View {
    let count: Int
    var onAction: () -> Void
    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(BoutiqueTheme.primary.opacity(0.1)).frame(width: 56, height: 56)
                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.title2).foregroundStyle(BoutiqueTheme.primary)
                    if count > 0 {
                        ZStack {
                            Circle().fill(Color.red).frame(width: 20, height: 20)
                            Text("\(count)").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        }.offset(x: 22, y: -22)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Returns Queue").font(BrandFont.body(16, weight: .bold)).foregroundStyle(Color.luxuryPrimaryText)
                    Text(count > 0 ? "\(count) items pending inspection" : "No pending returns").font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.luxurySecondaryText.opacity(0.5))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
        }
        .buttonStyle(LuxuryPressStyle())
    }
}
