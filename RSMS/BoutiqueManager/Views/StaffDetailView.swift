import SwiftUI

// MARK: - Staff Detail View with Customer Ratings

public struct StaffDetailView: View {
    let staff: User
    @Environment(\.presentationMode) var presentationMode

    @State private var ratings: [AssociateRating] = []
    @State private var appointments: [Appointment] = []
    @State private var isLoading = false
    @State private var errorMsg: String?
    @State private var selectedTab = 0

    public var body: some View {
        ZStack {
            BoutiqueTheme.offWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Close")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BoutiqueTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    Spacer()
                    
                    Text("Staff Details")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        // Action for Edit
                    }) {
                        Text("Edit")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(BoutiqueTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

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
                        
                        // Keep the existing appointments/reviews tabs below if needed
                        VStack(alignment: .leading, spacing: 14) {
                            Picker("Tab", selection: $selectedTab) {
                                Text("Appointments").tag(0)
                                Text("Reviews").tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding(.horizontal, 20)

                            if isLoading {
                                HStack { Spacer(); ProgressView(); Spacer() }
                                    .padding()
                            } else if let err = errorMsg {
                                Text(err)
                                    .font(.caption)
                                    .foregroundColor(BoutiqueTheme.error)
                                    .padding()
                            } else if selectedTab == 0 {
                                if appointments.isEmpty {
                                    HStack(spacing: 12) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                            .foregroundColor(BoutiqueTheme.border)
                                        Text("No appointments found")
                                            .font(.subheadline)
                                            .foregroundColor(BoutiqueTheme.textSecondary)
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(BoutiqueTheme.beige)
                                    .cornerRadius(14)
                                    .padding(.horizontal, 20)
                                } else {
                                    ForEach(appointments) { appointment in
                                        StaffAppointmentCard(appointment: appointment)
                                            .padding(.horizontal, 20)
                                    }
                                }
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
        }
        .navigationBarHidden(true)
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
                async let fetchedAppointments = DataService.shared.fetchAppointments(salesAssociateId: staff.id)
                let (r, a) = try await (fetchedRatings, fetchedAppointments)
                
                await MainActor.run {
                    self.ratings = r
                    self.appointments = a
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
struct StaffAppointmentCard: View {
    let appointment: Appointment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(appointment.customer?.name ?? "Unknown Client")
                    .font(.headline)
                    .foregroundColor(BoutiqueTheme.textPrimary)
                Spacer()
                Text(formatDate(appointment.appointmentDate))
                    .font(.caption)
                    .foregroundColor(BoutiqueTheme.textSecondary)
            }
            Text(appointment.notes ?? "General Visit")
                .font(.subheadline)
                .foregroundColor(BoutiqueTheme.textSecondary)
            
            Text(appointment.status.uppercased())
                .font(.caption2).fontWeight(.bold)
                .foregroundColor(appointment.status.lowercased() == "completed" ? BoutiqueTheme.success : BoutiqueTheme.primary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(appointment.status.lowercased() == "completed" ? BoutiqueTheme.success.opacity(0.1) : BoutiqueTheme.primary.opacity(0.1))
                .cornerRadius(6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }
}

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
