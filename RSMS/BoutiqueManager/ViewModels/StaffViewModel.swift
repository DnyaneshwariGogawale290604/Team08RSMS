import Foundation
import SwiftUI
import Combine

@MainActor
public class StaffViewModel: ObservableObject {
    @Published public var staffList: [User] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    public init() {}
    
    public func fetchStaff() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                self.staffList = try await DataService.shared.fetchStaff()
                self.isLoading = false
            } catch {
                print("Staff fetch error: \(error)")
                let errStr = error.localizedDescription
                if errStr.contains("stack depth limit") {
                    self.errorMessage = "Database RLS Policy Error: Please disable RLS on the 'users' table in the Supabase Dashboard to view staff."
                } else {
                    self.errorMessage = "Failed to load staff list. (\(errStr))"
                }
                self.isLoading = false
            }
        }
    }
    
    public func deleteStaff(id: UUID) {
        Task {
            do {
                try await DataService.shared.deleteStaff(id: id)
                self.fetchStaff()
            } catch {
                self.errorMessage = "Failed to delete staff."
            }
        }
    }
    
    public func addStaff(name: String, email: String, phone: String, role: User.Role) {
        isLoading = true
        let newUser = User(id: UUID(), name: name, email: email, phone: phone.isEmpty ? nil : phone, brandId: nil, role: role)
        
        Task {
            do {
                try await DataService.shared.addStaff(user: newUser)
                self.fetchStaff()
            } catch {
                self.errorMessage = "Failed to add staff member."
                self.isLoading = false
            }
        }
    }
    
    public func updateStaff(user: User) {
        isLoading = true
        Task {
            do {
                try await DataService.shared.updateStaff(user: user)
                self.fetchStaff()
            } catch {
                self.errorMessage = "Failed to update staff member."
                self.isLoading = false
            }
        }
    }
}
