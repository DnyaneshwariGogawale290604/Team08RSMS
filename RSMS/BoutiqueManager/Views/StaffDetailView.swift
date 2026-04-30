import SwiftUI

// MARK: - Staff Detail View with Customer Ratings

public struct StaffDetailView: View {
    let staff: User
    @Environment(\.presentationMode) var presentationMode

    @State private var ratings: [AssociateRating] = []

    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var selectedTab = 1

    public var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.offWhite.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Avatar + Name Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(BoutiqueTheme.border.opacity(0.4))
                                    .frame(width: 100, height: 100)
                                
                                Text(String((staff.name ?? "U").prefix(1)).uppercased())
                                    .font(.system(size: 40, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                            }
                            
                            VStack(spacing: 4) {
                                Text(staff.name ?? "Unnamed Staff")
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                                
                                Text(staff.role?.rawValue ?? "Staff Member")
                                    .font(.system(size: 16))
                                    .foregroundColor(BoutiqueTheme.textSecondary)
                                
                                HStack(spacing: 4) {
                                    HStack(spacing: 2) {
                                        ForEach(0..<5) { star in
                                            let filled = star < Int(averageRating)
                                            let half = !filled && (averageRating - Double(star) >= 0.5)
                                            Image(systemName: filled ? "star.fill" : (half ? "star.leadinghalf.filled" : "star"))
                                                .font(.system(size: 10))
                                                .foregroundColor(ratings.isEmpty ? BoutiqueTheme.border : .orange)
                                        }
                                    }
                                    
                                    Text(String(format: "%.1f", averageRating))
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(ratings.isEmpty ? BoutiqueTheme.textSecondary : BoutiqueTheme.textPrimary)
                                        .padding(.leading, 2)
                                    
                                    Text("(\(ratings.count) reviews)")
                                        .font(.system(size: 11))
                                        .foregroundColor(BoutiqueTheme.textSecondary)
                                }
                                .padding(.top, 2)
                            }
                        }
                        
                        // Details Card
                        VStack(spacing: 0) {
                            DetailRow(icon: "number", label: "Employee ID", value: "EMP-\(staff.id.uuidString.prefix(6).uppercased())")
                            Divider().padding(.leading, 56)
                            DetailRow(icon: "envelope.fill", label: "Email", value: staff.email ?? "N/A")
                            Divider().padding(.leading, 56)
                            DetailRow(icon: "phone.fill", label: "Phone", value: staff.phone ?? "N/A")
                            Divider().padding(.leading, 56)
                            DetailRow(icon: "building.2.fill", label: "Role", value: staff.role?.rawValue ?? "N/A")
                        }
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        .padding(.horizontal, 20)
                        
                        // Performance and reviews
                        VStack(alignment: .leading, spacing: 14) {
                        AppSegmentedControl(
                            options: [
                                AppSegmentedOption(id: 1, title: "Reviews", badge: ratings.count > 0 ? "\(ratings.count)" : nil)
                            ],
                            selection: $selectedTab
                        )
                        .padding(.horizontal, 20)

                            if isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding()
                            } else if let err = errorMsg {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(BoutiqueTheme.error)
                                    .padding()

                            } else {
                                if ratings.isEmpty {
                                    HStack(spacing: 12) {
                                        Image(systemName: "star.slash")
                                            .foregroundColor(BoutiqueTheme.border)
                                        Text("No customer ratings yet")
                                            .font(.subheadline)
                                            .foregroundColor(BoutiqueTheme.textSecondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(BoutiqueTheme.beige)
                                    .cornerRadius(14)
                                    .padding(.horizontal, 20)
                                } else {
                                    ForEach(ratings) { rating in
                                        StaffRatingCard(rating: rating)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Staff Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                }
            }
        }
        .onAppear { loadData() }
    }

    private var averageRating: Double {
        guard !ratings.isEmpty else { return 0 }
        return ratings.reduce(0) { $0 + $1.ratingValue } / Double(ratings.count)
    }

    private func loadData() {
        isLoading = true
        errorMsg = nil
        Task {
            do {
                async let fetchedRatings = DataService.shared.fetchStaffRatings(salesAssociateId: staff.id)
                let r = try await fetchedRatings
                
                await MainActor.run {
                    self.ratings = r
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMsg = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(CatalogTheme.primaryText)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(BoutiqueTheme.textSecondary)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(BoutiqueTheme.textPrimary)
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
}

// Sub-views for Appointment / Rating cards


struct StaffRatingCard: View {
    let rating: AssociateRating
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < Int(rating.ratingValue) ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.0))
                    }
                }
                Spacer()
                if let d = rating.createdAt {
                    Text(d)
                        .font(.caption2)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
            }
            
            if let fb = rating.feedbackText, !fb.isEmpty {
                Text(fb)
                    .font(.subheadline)
                    .foregroundColor(BoutiqueTheme.textPrimary)
                    .italic()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
}

struct StaffProfileHeader: View {
    let staff: User
    let averageRating: Double
    let ratingCount: Int
    var body: some View { EmptyView() } // Obsoleted but kept to avoid compilation errors if used elsewhere
}
