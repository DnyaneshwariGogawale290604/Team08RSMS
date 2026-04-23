import SwiftUI

struct SalesAssociateTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var orderStore = SharedOrderStore()

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            SalesAssociateDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            SalesAssociateAppointmentsView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar.badge.clock")
                }

            SalesAssociateOrdersView()
                .tabItem {
                    Label("Orders", systemImage: "shippingbox")
                }

            SalesAssociateClientsView()
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .tint(.brandWarmBlack)
        .environmentObject(orderStore)
    }

    private var accountTab: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.brandWarmGrey)

                    Text("Sales Associate")
                        .font(BrandFont.display(24))
                        .foregroundStyle(Color.brandWarmBlack)

                    Button {
                        Task { await sessionViewModel.signOut() }
                    } label: {
                        Text("Logout")
                            .font(BrandFont.body(15, weight: .semibold))
                            .foregroundStyle(Color.brandOffWhite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.brandWarmBlack)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Account")
        }
    }
}
