import Foundation
import Supabase
import Auth
#if canImport(UIKit)
import UIKit
#endif

/// Service for handling file uploads to Supabase Storage via direct URLSession.
/// Uses the REST API directly to avoid the Supabase SDK's socket-level issues
/// with large binary payloads on the iOS Simulator (EMSGSIZE).
public final class StorageService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = StorageService()

    // Supabase project details – matches SupabaseManager.swift
    private let supabaseURL = "https://ionszphvxhffqfwlohiv.supabase.co"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTMyNzQsImV4cCI6MjA5MTg4OTI3NH0.KYYW_eEJIBJQB1-7fvxUo7N4GCxN9PzpROZQoef0xh0"

    private init() {}

    // MARK: - Public API

    /// Uploads a UIImage to Supabase Storage and returns the public URL.
    /// Uses raw URLSession HTTP to avoid SDK socket limitations.
    /// Returns nil (non-throwing) if the upload fails, so callers can proceed gracefully.
    public func uploadImage(
        _ image: UIImage,
        toBucket bucket: String,
        folder: String = "proofs"
    ) async -> String? {
        do {
            // 1. Aggressively downscale + compress to keep payload small
            let resized = resizeImage(image, maxDimension: 600)
            guard let data = resized.jpegData(compressionQuality: 0.5) else {
                print("[StorageService] JPEG compression failed")
                return nil
            }
            print("[StorageService] Uploading \(data.count / 1024) KB")

            // 2. Build the REST endpoint
            let fileName = "\(folder)/\(UUID().uuidString).jpg"
            guard let url = URL(string: "\(supabaseURL)/storage/v1/object/\(bucket)/\(fileName)") else {
                return nil
            }

            // 3. Get the current auth token (falls back to anon key)
            var authToken = anonKey
            if let session = try? await SupabaseManager.shared.client.auth.session {
                authToken = session.accessToken
            }

            // 4. Build a URLRequest with a generous timeout
            var request = URLRequest(url: url, timeoutInterval: 60)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
            request.httpBody = data

            // 5. Send using URLSession (bypasses Supabase SDK socket layer)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else {
                let http = response as? HTTPURLResponse
                print("[StorageService] Upload failed, status: \(http?.statusCode ?? -1)")
                return nil
            }

            // 6. Build the public URL
            let publicUrl = "\(supabaseURL)/storage/v1/object/public/\(bucket)/\(fileName)"
            print("[StorageService] Upload succeeded: \(publicUrl)")
            return publicUrl

        } catch {
            print("[StorageService] Upload error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Helpers

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let ratio = maxDimension / longest
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
