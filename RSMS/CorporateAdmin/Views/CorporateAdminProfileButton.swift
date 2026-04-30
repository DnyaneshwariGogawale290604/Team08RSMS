import SwiftUI

public struct CorporateAdminProfileButton: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @State private var showingAccountSheet = false

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        Button {
            showingAccountSheet = true
        } label: {
            AppProfileToolbarButton()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAccountSheet) {
            CorporateAdminAccountSheet(sessionViewModel: sessionViewModel)
        }
    }
}
