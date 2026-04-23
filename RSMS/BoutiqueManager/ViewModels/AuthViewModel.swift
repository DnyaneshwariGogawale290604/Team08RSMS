import Foundation
import SwiftUI
import Combine

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var name = ""
    @Published public var phone = ""
    @Published public var isAuthenticated = false
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    public var currentUser: User?
    
    public init() {}
    
    public func login() {
        guard !email.isEmpty, !password.isEmpty else {
            self.errorMessage = "Please enter both email and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await AuthService.shared.login(email: email, password: password)
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to login. Please try again or check your credentials."
                self.isLoading = false
            }
        }
    }
    
    public func register() {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            self.errorMessage = "Please enter name, email, and password."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await AuthService.shared.register(email: email, password: password, name: name, phone: phone)
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to register. Please try again."
                self.isLoading = false
                print(error)
            }
        }
    }
    
    public func logout() {
        Task {
            try? await AuthService.shared.logout()
            self.isAuthenticated = false
            self.currentUser = nil
            self.email = ""
            self.password = ""
        }
    }
}
