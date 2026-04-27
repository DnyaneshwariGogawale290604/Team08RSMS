import SwiftUI

public struct StaffManagementView: View {
    @EnvironmentObject var staffVM: StaffViewModel
    @State private var showAddStaff = false
    @State private var staffToEdit: User?
    @State private var staffToView: User?       // tapped → detail sheet

    public var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.offWhite.ignoresSafeArea()

                if staffVM.isLoading && staffVM.staffList.isEmpty {
                    ProgressView()
                } else if staffVM.staffList.isEmpty && staffVM.errorMessage != nil {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.largeTitle).foregroundColor(BoutiqueTheme.border)
                        Text(staffVM.errorMessage ?? "")
                            .foregroundColor(BoutiqueTheme.error)
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .padding(.horizontal)
                        Button("Retry") { staffVM.fetchStaff() }
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                } else {
                    VStack(spacing: 0) {
                        if let error = staffVM.errorMessage, !staffVM.staffList.isEmpty {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(BoutiqueTheme.error)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .frame(maxWidth: .infinity)
                                .background(BoutiqueTheme.error.opacity(0.08))
                        }

                        List {
                            ForEach(staffVM.staffList) { staff in
                                // Tap → detail (ratings), swipe/edit button → edit form
                                Button(action: { staffToView = staff }) {
                                    StaffRow(staff: staff)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .padding(.vertical, 6)
                                .swipeActions(edge: .leading) {
                                    Button { staffToEdit = staff } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(BoutiqueTheme.textPrimary)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        staffVM.deleteStaff(id: staff.id)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Staff")
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddStaff = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                }
            }
            // Detail / ratings sheet (tap)
            .sheet(item: $staffToView) { staff in
                StaffDetailView(staff: staff)
            }
            // Add new staff sheet
            .sheet(isPresented: $showAddStaff) {
                StaffFormView(staffVM: staffVM)
            }
            // Edit staff sheet (swipe-left)
            .sheet(item: $staffToEdit) { staff in
                StaffFormView(staffVM: staffVM, userToEdit: staff)
            }
            .onAppear {
                staffVM.fetchStaff()
            }
        }
    }
}

// MARK: - Staff Row

struct StaffRow: View {
    let staff: User

    var body: some View {
        HStack(spacing: 14) {
            // Avatar circle with initial
            ZStack {
                Circle()
                    .fill(BoutiqueTheme.surface)
                    .frame(width: 46, height: 46)
                Text(String((staff.name ?? "U").prefix(1)).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(BoutiqueTheme.textPrimary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(staff.name ?? "Unnamed Staff")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(BoutiqueTheme.textPrimary)

                if let sales = staff.totalSales {
                    Text(formatCurrency(sales))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(BoutiqueTheme.primary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if staff.averageRating != nil {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.9, green: 0.7, blue: 0.0))
                        
                        Text(String(format: "%.1f", staff.averageRating!))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .foregroundColor(BoutiqueTheme.border)
                .font(.caption)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}
