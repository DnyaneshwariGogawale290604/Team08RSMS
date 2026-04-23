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
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(CatalogTheme.deepAccent)
                .frame(width: AppTheme.toolbarButtonSize, height: AppTheme.toolbarButtonSize)
                .background(Circle().fill(CatalogTheme.surface))
                .accessibilityLabel("Account")
        }
        .sheet(isPresented: $showingAccountSheet) {
            CorporateAdminAccountSheet(sessionViewModel: sessionViewModel)
        }
    }
}
