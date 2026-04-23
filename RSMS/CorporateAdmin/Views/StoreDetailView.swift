import SwiftUI

public struct StoreDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: StoreViewModel
    private let storeId: UUID

    @State private var selectedTab: Int = 0
    @State private var storeDetails: Store
    @State private var isLoadingDetails = false
    @State private var localErrorMessage: String?

    public init(viewModel: StoreViewModel, store: Store) {
        self.viewModel = viewModel
        self.storeId = store.id
        self._storeDetails = State(initialValue: store)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            
            pickerView
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            if isLoadingDetails && selectedTab == 0 {
                LoadingView(message: "Loading Store Details...")
                    .frame(maxHeight: .infinity)
            } else {
                tabContent
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color.brandOffWhite.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("") // Clear title to prevent leak
        .task {
            await loadStoreDetails()
        }
        .alert(
            "Store Error",
            isPresented: Binding(
                get: { localErrorMessage != nil },
                set: { if !$0 { localErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                localErrorMessage = nil
            }
        } message: {
            Text(localErrorMessage ?? "Unable to load store details.")
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(storeDetails.displayName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            // Empty space for balance
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var pickerView: some View {
        HStack(spacing: 4) {
            let titles = ["Overview", "Inventory", "Assignments", "Staff"]
            ForEach(0..<titles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    Text(titles[index])
                        .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                        .foregroundColor(selectedTab == index ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == index ? Color.white : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0:
            StoreOverviewTab(
                viewModel: viewModel,
                store: storeDetails,
                refreshStore: {
                    await loadStoreDetails()
                }
            )
        case 1:
            StoreInventoryTab(storeId: storeId)
        case 2:
            StoreProductsTab(storeId: storeId)
        default:
            StoreStaffTab(storeId: storeId)
        }
    }

    private func loadStoreDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            storeDetails = try await viewModel.fetchStore(id: storeId)
            localErrorMessage = nil
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }
}
