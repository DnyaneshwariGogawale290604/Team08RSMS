import SwiftUI

public struct ContentView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    public init() {}

    public var body: some View {
        Group {
            if sessionViewModel.isLoading {
                LoadingView(message: "Checking session...")
            } else if let role = sessionViewModel.role {
                switch role {
                case .corporateAdmin:
                    CorporateAdminTabView(sessionViewModel: sessionViewModel)
                case .inventoryManager:
                    InventoryManagerTabView(sessionViewModel: sessionViewModel)
                case .boutiqueManager:
                    MainDashboardView(sessionViewModel: sessionViewModel)
                case .salesAssociate:
                    SalesAssociateTabView(sessionViewModel: sessionViewModel)
                }
            } else {
                LoginView(viewModel: sessionViewModel)
            }
        }
        .tint(Color.appAccent)
        .task {
            await sessionViewModel.restoreSession()
        }
        .animation(.easeInOut, value: sessionViewModel.role)
    }
}
