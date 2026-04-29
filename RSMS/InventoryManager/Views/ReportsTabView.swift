import SwiftUI

public struct ReportsTabView: View {
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Reports")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color.appPrimaryText)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        
                        Text("Analytics and reporting functionality will be built here.")
                            .foregroundColor(Color.appSecondaryText)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ReportsTabView_Previews: PreviewProvider {
    static var previews: some View {
        ReportsTabView()
    }
}
