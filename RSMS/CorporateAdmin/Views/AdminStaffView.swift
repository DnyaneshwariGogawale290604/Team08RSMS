import SwiftUI

struct AdminStaffView: View {
    @StateObject private var sessionViewModel = SessionViewModel()

    var body: some View {
        AdminManagementView(sessionViewModel: sessionViewModel)
    }
}

struct AdminStaffView_Previews: PreviewProvider {
    static var previews: some View {
        AdminStaffView()
    }
}
