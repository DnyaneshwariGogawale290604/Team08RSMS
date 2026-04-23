import SwiftUI

struct AdminCatalogView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        ProductListView(sessionViewModel: sessionViewModel)
    }
}

struct AdminCatalogView_Previews: PreviewProvider {
    static var previews: some View {
        AdminCatalogView()
    }
}
