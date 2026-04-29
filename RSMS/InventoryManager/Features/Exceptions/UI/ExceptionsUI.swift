import SwiftUI

public struct ExceptionsDashboardView: View {
    @StateObject private var engine = ExceptionEngine.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary Cards
                        HStack(spacing: 12) {
                            ExceptionSummaryCard(title: "Missing", count: engine.missingCount, color: .red, icon: "questionmark.folder.fill")
                            ExceptionSummaryCard(title: "Mismatch", count: engine.mismatchCount, color: .orange, icon: "arrow.left.arrow.right")
                            ExceptionSummaryCard(title: "Duplicate", count: engine.duplicateCount, color: .yellow, icon: "doc.on.doc.fill")
                        }
                        .padding(.horizontal)
                        
                        // List of Exceptions
                        if engine.exceptions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                Text("No Exceptions Found")
                                    .font(.headline)
                                Text("Inventory reconciliation is perfectly balanced.")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                            .padding(.top, 60)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(engine.exceptions) { exception in
                                    ExceptionRow(exception: exception)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Exception Queue")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
    }
}

struct ExceptionSummaryCard: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Spacer()
                    Text("\(count)")
                        .font(.title2.bold())
                        .foregroundColor(.appPrimaryText)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
        }
    }
}

struct ExceptionRow: View {
    let exception: ExceptionRecord
    @StateObject private var engine = ExceptionEngine.shared
    @State private var isResolving = false
    
    var body: some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(exception.type.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(severityColor)
                    
                    Spacer()
                    
                    Text(exception.severity.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(severityColor.opacity(0.15))
                        .foregroundColor(severityColor)
                        .cornerRadius(6)
                }
                
                Text("RFID: \(exception.rfid)")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                
                if let item = exception.item {
                    Text("\(item.productName) (\(item.category))")
                        .font(.subheadline)
                        .foregroundColor(.appPrimaryText)
                }
                
                // Context-specific text
                switch exception.type {
                case .missing:
                    Text("Expected in: \(exception.expectedLocation ?? "Unknown")")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                case .mismatch:
                    Text("Expected: \(exception.expectedLocation ?? "") → Found: \(exception.scannedLocation ?? "")")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                case .duplicate:
                    Text("Scanned multiple times in \(exception.scannedLocation ?? "Unknown")")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                case .damaged:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reported damaged at boutique")
                            .font(.caption2)
                        if let asn = exception.asnNumber {
                            Text("Shipment: \(asn)")
                                .font(.caption2.bold())
                                .foregroundColor(.appAccent)
                        }
                    }
                    .foregroundColor(.appSecondaryText)
                case .shortage:
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Incomplete shipment received")
                            .font(.caption2)
                        if let asn = exception.asnNumber {
                            Text("Shipment: \(asn)")
                                .font(.caption2.bold())
                                .foregroundColor(.appAccent)
                        }
                    }
                    .foregroundColor(.appSecondaryText)
                case .certificationMissing:
                    Text("Missing authenticity certificate")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                case .certificationExpired:
                    Text("Certification expired or invalid")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                @unknown default:
                    Text("Unknown exception type")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                }
                
                if let imageUrl = exception.imageUrl {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo Proof")
                            .font(.caption2.bold())
                            .foregroundColor(.appSecondaryText)
                        
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                                .cornerRadius(8)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 120)
                                .overlay(ProgressView())
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                }
                
                Divider()
                
                // Resolution Actions
                HStack(spacing: 12) {
                    if isResolving {
                        ProgressView().progressViewStyle(CircularProgressViewStyle())
                    } else {
                        resolutionButtons
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var resolutionButtons: some View {
        switch exception.type {
        case .missing:
            ActionButton(title: "Found It", color: .green) {
                resolve(.markFound)
            }
            ActionButton(title: "Confirm Lost", color: .red) {
                resolve(.confirmMissing)
            }
        case .mismatch:
            ActionButton(title: "Update Location", color: .blue) {
                resolve(.updateLocation)
            }
            ActionButton(title: "Ignore", color: .gray) {
                resolve(.ignoreDuplicate) // Same as ignoring
            }
        case .duplicate:
            ActionButton(title: "Dismiss", color: .gray) {
                resolve(.ignoreDuplicate)
            }
        case .damaged:
            ActionButton(title: "File Claim", color: .blue) {
                resolve(.fileInsuranceClaim)
            }
            ActionButton(title: "Scrap Item", color: .red) {
                resolve(.markAsScrapped)
            }
        case .shortage:
            ActionButton(title: "Approve Shortage", color: .green) {
                resolve(.approveShortage)
            }
            ActionButton(title: "Reship Missing", color: .blue) {
                // Future workflow
            }
        case .certificationMissing, .certificationExpired:
            ActionButton(title: "Dismiss", color: .gray) {
                resolve(.ignoreDuplicate)
            }
        @unknown default:
            EmptyView()
        }
    }
    
    private func resolve(_ action: ExceptionResolutionAction) {
        isResolving = true
        Task {
            do {
                try await engine.resolveException(exceptionId: exception.id, action: action)
            } catch {
                print("Failed to resolve exception: \(error)")
            }
            await MainActor.run { isResolving = false }
        }
    }
    
    private var severityColor: Color {
        switch exception.severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .yellow
        @unknown default: return .gray
        }
    }
}

struct ActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.15))
                .foregroundColor(color)
                .cornerRadius(8)
        }
    }
}
