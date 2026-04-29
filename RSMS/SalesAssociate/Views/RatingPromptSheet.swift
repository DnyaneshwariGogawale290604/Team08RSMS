import SwiftUI

// MARK: - Rating Prompt Sheet
// Shown after a successful checkout to collect customer satisfaction rating.
struct RatingPromptSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedRating: Int = 0
    @State private var feedback: String = ""
    @State private var submitted = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Header illustration
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#C8913A").opacity(0.12))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "star.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Color(hex: "#C8913A"))
                            }
                            Text("How was the experience?")
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.luxuryPrimaryText)
                                .multilineTextAlignment(.center)
                            Text("Rate your customer's visit to help improve service quality.")
                                .font(BrandFont.body(14))
                                .foregroundStyle(Color.luxurySecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .padding(.top, 24)

                        if submitted {
                            // Success state
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(Color(hex: "#4A7C59"))
                                Text("Rating Submitted!")
                                    .font(.system(size: 20, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color.luxuryPrimaryText)
                                Text("Thank you for the feedback.")
                                    .font(BrandFont.body(14))
                                    .foregroundStyle(Color.luxurySecondaryText)
                            }
                            .padding(.vertical, 24)
                        } else {
                            // Star selector
                            VStack(spacing: 20) {
                                HStack(spacing: 14) {
                                    ForEach(1...5, id: \.self) { star in
                                        Button {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                                selectedRating = star
                                            }
                                        } label: {
                                            Image(systemName: star <= selectedRating ? "star.fill" : "star")
                                                .font(.system(size: 38))
                                                .foregroundStyle(
                                                    star <= selectedRating
                                                    ? Color(hex: "#C8913A")
                                                    : Color.luxuryDivider
                                                )
                                                .scaleEffect(star <= selectedRating ? 1.15 : 1.0)
                                                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: selectedRating)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                // Star label
                                if selectedRating > 0 {
                                    Text(ratingLabel)
                                        .font(BrandFont.body(13, weight: .medium))
                                        .foregroundStyle(Color(hex: "#C8913A"))
                                        .transition(.opacity.combined(with: .scale))
                                        .animation(.easeInOut, value: selectedRating)
                                }
                            }
                            .padding(.vertical, 8)

                            // Feedback field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Feedback (Optional)")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                                    .padding(.horizontal, 16)

                                TextField("Add notes about the visit...", text: $feedback, axis: .vertical)
                                    .lineLimit(3...5)
                                    .font(BrandFont.body(14))
                                    .foregroundStyle(Color.luxuryPrimaryText)
                                    .padding(14)
                                    .background(Color.luxurySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.luxuryDivider, lineWidth: 0.5))
                                    .padding(.horizontal, 16)
                            }

                            // Error banner
                            if let err = vm.errorMessage {
                                ErrorBanner(message: err) { vm.errorMessage = nil }
                                    .padding(.horizontal, 16)
                            }

                            // Submit button
                            Button {
                                Task { await submitRating() }
                            } label: {
                                HStack {
                                    if vm.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.system(size: 14))
                                        Text("Submit Rating")
                                            .font(BrandFont.body(15, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(selectedRating == 0
                                    ? Color.luxuryPrimaryText.opacity(0.3)
                                    : Color.luxuryDeepAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal, 16)
                            }
                            .disabled(selectedRating == 0 || vm.isLoading)

                            // Skip button
                            Button("Skip for now") {
                                dismiss()
                            }
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .padding(.bottom, 8)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Rate Experience")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.luxuryPrimaryText)
                }
            }
        }
    }

    private var ratingLabel: String {
        switch selectedRating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent!"
        default: return ""
        }
    }

    private func submitRating() async {
        await vm.submitRating(rating: Double(selectedRating), feedback: feedback)
        if vm.errorMessage == nil {
            withAnimation { submitted = true }
            // Auto-dismiss after 1.5s
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        }
    }
}
