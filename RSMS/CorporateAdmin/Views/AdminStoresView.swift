import SwiftUI

struct AdminStoresView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        StoreListView(sessionViewModel: sessionViewModel)
    }
}

struct AdminStoresView_Previews: PreviewProvider {
    static var previews: some View {
        AdminStoresView()
    }
}
