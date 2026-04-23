import SwiftUI

// MARK: - Main Appointments Tab View
struct SalesAssociateAppointmentsView: View {
    @EnvironmentObject var orderStore: SharedOrderStore
    @StateObject private var vm = AppointmentsViewModel()
    @State private var showNewAppointment = false
    @State private var selectedAppointment: Appointment? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                if vm.isLoading && vm.appointments.isEmpty {
                    LoadingView(message: "Loading appointments...")
                } else if vm.appointments.isEmpty {
                    appointmentsEmptyState
                } else {
                    appointmentsList
                }

                // Floating "New Appointment" button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showNewAppointment = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("New")
                                    .font(BrandFont.body(14, weight: .semibold))
                            }
                            .foregroundStyle(Color.brandOffWhite)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            .background(Color.brandWarmBlack)
                            .clipShape(Capsule())
                            .shadow(color: Color.brandWarmBlack.opacity(0.25), radius: 10, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENTS")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
            }
            .sheet(isPresented: $showNewAppointment, onDismiss: {
                Task { await vm.fetchAppointments() }
            }) {
                NewAppointmentSheet(vm: vm)
            }
            .sheet(item: $selectedAppointment) { appt in
                AppointmentDetailSheet(appointment: appt, vm: vm)
                    .environmentObject(orderStore)
            }
            .alert("Success", isPresented: Binding(
                get: { vm.successMessage != nil },
                set: { if !$0 { vm.successMessage = nil } }
            )) {
                Button("OK") { vm.successMessage = nil }
            } message: { Text(vm.successMessage ?? "") }
            .alert("Error", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: { Text(vm.errorMessage ?? "") }
            .task { await vm.fetchAppointments() }
            .refreshable { await vm.fetchAppointments() }
        }
    }

    private var appointmentsList: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(vm.appointments) { appt in
                    AppointmentCard(appointment: appt)
                        .onTapGesture { selectedAppointment = appt }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    private var appointmentsEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(Color.brandPebble)
            Text("No upcoming appointments")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(Color.brandWarmBlack)
            Text("Tap \"New\" to schedule a client appointment.")
                .font(BrandFont.body(14))
                .foregroundStyle(Color.brandWarmGrey)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Appointment Card
struct AppointmentCard: View {
    let appointment: Appointment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: client name + duration + category
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(appointment.customer?.name ?? "Unknown Client")
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.brandWarmBlack)
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandWarmGrey)
                        Text(appointment.displayDateTime)
                            .font(BrandFont.body(12))
                            .foregroundStyle(Color.brandWarmGrey)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if let cat = appointment.customer?.customerCategory {
                        Text(cat.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.8)
                            .foregroundStyle(Color(hex: "#C8913A"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#C8913A").opacity(0.12))
                            .clipShape(Capsule())
                    }
                    Text(appointment.durationDisplay)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.brandWarmGrey)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.brandPebble.opacity(0.25))
                        .clipShape(Capsule())
                }
            }

            // Product interest chips
            if let products = appointment.appointmentProducts, !products.isEmpty {
                Divider().background(Color.brandPebble.opacity(0.5))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(products) { item in
                            if let name = item.product?.name {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                        .font(.system(size: 9))
                                    Text(name)
                                        .font(.system(size: 11, weight: .medium))
                                    if item.quantity > 1 {
                                        Text("×\(item.quantity)")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.brandWarmGrey)
                                    }
                                }
                                .foregroundStyle(Color.brandWarmBlack)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.brandLinen)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.brandPebble, lineWidth: 0.5))
                            }
                        }
                    }
                }
            }

            // Notes snippet
            if let notes = appointment.notes, !notes.isEmpty {
                Text(notes)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color.brandWarmGrey)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
    }
}
