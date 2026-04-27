import SwiftUI
import Combine

@MainActor
public class StoreProfileViewModel: ObservableObject {
    @Published public var store: Store?
    @Published public var storeName = ""
    @Published public var location = ""
    @Published public var salesTarget = ""
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    public init() {}
    
    public func fetchStore() {
        isLoading = true
        Task {
            do {
                let stores = try await DataService.shared.fetchStores()
                if let first = stores.first {
                    self.store = first
                    self.storeName = first.name
                    self.location = first.location
                    self.salesTarget = String(format: "%.0f", first.salesTarget ?? 0)
                }
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load store."
                self.isLoading = false
            }
        }
    }
    
    public func saveStore() {
        guard let s = store else { return }
        isLoading = true
        
        let target = Double(salesTarget) ?? s.salesTarget
        let updatedStore = Store(id: s.id, name: storeName, location: location, brandId: s.brandId, salesTarget: target)
        
        Task {
            do {
                try await DataService.shared.updateStore(store: updatedStore)
                self.store = updatedStore
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to update store."
                self.isLoading = false
            }
        }
    }
}

public struct StoreProfileView: View {
    @StateObject private var vm = StoreProfileViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        Form {
            if vm.isLoading && vm.store == nil {
                ProgressView()
            } else {
                
                Section(header: Text("Goals")) {
                    TextField("Sales Target (₹)", text: $vm.salesTarget)
                        .keyboardType(.numberPad)
                }
                
                Section(header: Text("Store Information")) {
                    TextField("Store Name", text: $vm.storeName)
                    TextField("Location", text: $vm.location)
                }
                
                
                if let error = vm.errorMessage {
                    Section {
                        Text(error).foregroundColor(BoutiqueTheme.error).font(.caption)
                    }
                }
                
                Section {
                    Button(action: {
                        vm.saveStore()
                        // Small delay to allow view update
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        if vm.isLoading {
                            ProgressView()
                        } else {
                            Text("Save Configurations")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .appPrimaryButtonChrome()
                        }
                    }
                    .disabled(vm.isLoading)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Boutique Details")
        .background(BoutiqueTheme.background.ignoresSafeArea())
        .tint(.appAccent)
        .onAppear {
            vm.fetchStore()
        }
    }
}
