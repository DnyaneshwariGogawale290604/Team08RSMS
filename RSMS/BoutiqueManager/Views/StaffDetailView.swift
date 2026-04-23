import SwiftUI

// MARK: - Staff Detail View with Customer Ratings

public struct StaffDetailView: View {
    let staff: User
    @Environment(\.presentationMode) var presentationMode

    @State private var ratings: [AssociateRating] = []
    @State private var isLoading = false
    @State private var errorMsg: String?

    public var body: some View {
        NavigationView {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar + name header
                        StaffProfileHeader(staff: staff, averageRating: averageRating, ratingCount: ratings.count)

                        // Ratings section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("CUSTOMER RATINGS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.textSecondary)
                                    .tracking(1.2)
                                Spacer()
                                if !ratings.isEmpty {
                                    Text("\(ratings.count) review\(ratings.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }

                            if isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding()
                            } else if let err = errorMsg {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(Theme.error)
                                    .padding()
                            } else if ratings.isEmpty {
                                HStack(spacing: 12) {
                                    Image(systemName: "star.slash")
                                        .foregroundColor(Theme.border)
                                    Text("No customer ratings yet")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Theme.beige)
                                .cornerRadius(14)
                            } else {
                                ForEach(ratings) { rating in
                                    RatingCard(rating: rating)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Staff Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear { loadRatings() }
        }
    }

    private var averageRating: Double {
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0) { $0 + $1.ratingValue } / Double(ratings.count)
    }

    private func loadRatings() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let fetched = try await DataService.shared.fetchStaffRatings(salesAssociateId: staff.id)
                await MainActor.run {
                    self.ratings = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = "Could not load ratings. (\(error.localizedDescription))"
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Profile Header

private struct StaffProfileHeader: View {
    let staff: User
    let averageRating: Double
    let ratingCount: Int

    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Theme.beige)
                    .frame(width: 80, height: 80)
                Text(String((staff.name ?? "U").prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
            }

            VStack(spacing: 4) {
                Text(staff.name ?? "Unnamed Staff")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                Text(staff.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                if let phone = staff.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            // Star rating summary
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: starIcon(for: star, avg: averageRating))
                        .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.0))
                        .font(.body)
                }
                Text(ratingCount > 0 ? String(format: "%.1f", averageRating) : "–")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                    .padding(.leading, 4)
                if ratingCount > 0 {
                    Text("/ 5")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func starIcon(for star: Int, avg: Double) -> String {
        if Double(star) <= avg { return "star.fill" }
        if Double(star) - avg < 1 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: - Individual Rating Card

private struct RatingCard: View {
    let rating: AssociateRating

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                // Stars
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= rating.ratingValue ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.0))
                    }
                }
                Text(String(format: "%.0f/5", rating.ratingValue))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                if let date = rating.createdAt {
                    Text(formatDate(date))
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }

            if let feedback = rating.feedbackText, !feedback.isEmpty {
                Text("\"\(feedback)\"")
                    .font(.subheadline.italic())
                    .foregroundColor(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }

    private func formatDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fmt.date(from: iso) {
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: date)
        }
        return String(iso.prefix(10))
    }
}



