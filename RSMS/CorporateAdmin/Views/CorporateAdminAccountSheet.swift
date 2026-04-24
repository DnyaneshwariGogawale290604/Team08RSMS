import SwiftUI

public struct CorporateAdminAccountSheet: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        NavigationView {
            CorporateAdminAccountView(sessionViewModel: sessionViewModel)
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

private struct CorporateAdminAccountView: View {
    @ObservedObject var sessionViewModel: SessionViewModel

    var body: some View {
        ZStack {
            Color.brandOffWhite.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 72))
                    .foregroundColor(CatalogTheme.secondaryText)

                Text("Corporate Admin")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(CatalogTheme.primaryText)

                Button {
                    Task { await sessionViewModel.signOut() }
                } label: {
                    Text("Logout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .appPrimaryButtonChrome()
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
