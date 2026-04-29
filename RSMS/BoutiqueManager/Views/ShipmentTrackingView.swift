import SwiftUI

/// Boutique Manager's view for all incoming shipments and their GRN status.
public struct ShipmentTrackingView: View {
    @StateObject private var viewModel = BoutiqueShipmentViewModel()
    @State private var selectedSegment = 0
    @State private var shipmentForGRN: Shipment? = nil
    @State private var lastGRN: String? = nil
    @State private var showGRNBanner = false

    @StateObject private var exceptionEngine = ExceptionEngine.shared

    private let segments = ["Approved", "Rejected", "Order"]

    public init() {}

    private var filteredRequests: [ProductRequest] {
        switch selectedSegment {
        case 0: // Approved
            return viewModel.allRequests.filter { $0.status.lowercased() == "approved" }
        case 1: // Rejected
            return viewModel.allRequests.filter { $0.status.lowercased() == "rejected" }
        case 2: // Order (Pending)
            return viewModel.allRequests.filter { $0.status.lowercased() == "pending" }
        default:
            return []
        }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented Control
                    ShipmentSegmentedControl(selected: $selectedSegment, segments: segments)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    if viewModel.isLoading && viewModel.allRequests.isEmpty {
                        Spacer()
                        LoadingView(message: "Loading details...")
                        Spacer()
                    } else if let err = viewModel.errorMessage {
                        errorView(message: err)
                    } else if filteredRequests.isEmpty {
                        emptyView
                    } else {
                        requestsList
                    }
                }

                // GRN Banner
                if showGRNBanner, let grn = lastGRN {
                    grnBanner(grnNumber: grn)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Shipments")
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                await viewModel.loadAll()
            }
            .refreshable { await viewModel.loadAll() }
            .sheet(item: $shipmentForGRN) { shipment in
                GRNFormSheet(shipment: shipment) { grn in
                    lastGRN = grn
                    withAnimation(.spring()) { showGRNBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation { showGRNBanner = false }
                    }
                }
                .environmentObject(viewModel)
            }
        }
    }

    // MARK: - Sub-views

    private var requestsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredRequests) { request in
                    requestCard(for: request)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func requestCard(for request: ProductRequest) -> some View {
        let shipment = viewModel.incomingShipments.first { $0.requestId == request.id }
        let existingGRN = shipment.flatMap { viewModel.grn(forShipment: $0) }
        let hasGRN = existingGRN != nil

        // Detect issue from GRN record first, fall back to embedded shipment notes tag
        let issueCondition: GoodsReceivedNote.GRNCondition? = {
            if let condition = existingGRN?.condition, condition != .good {
                return condition
            }
            // Fallback: read the ISSUE tag the boutique wrote into shipment.notes
            if let notes = shipment?.notes {
                if notes.contains("ISSUE:damaged") { return .damaged }
                if notes.contains("ISSUE:partial") { return .partial }
            }
            return nil
        }()

        VStack(alignment: .leading, spacing: 12) {
            // Header: Product + Status
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.product?.name ?? "Unknown Product")
                        .font(.headline)
                        .foregroundColor(BoutiqueTheme.textPrimary)
                    
                    Text("Qty: \(request.requestedQuantity)")
                        .font(.subheadline)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
                Spacer()
                if let issue = issueCondition {
                    // Issue overrides everything — always show the problem
                    let label = issue == .damaged ? "Damaged Goods" : "Partial Shipment"
                    issueChip(label)
                } else if let s = shipment {
                    // Use the live shipment status
                    shipmentStatusChip(s.status)
                } else {
                    // No shipment yet — show request status
                    statusChip(request.status)
                }
            }

            if let rejectionReason = request.rejectionReason, !rejectionReason.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.caption)
                        Text("Order Rejected")
                            .font(.caption).fontWeight(.bold)
                    }
                    .foregroundColor(BoutiqueTheme.error)
                    
                    Text(rejectionReason)
                        .font(.caption2)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BoutiqueTheme.error.opacity(0.1))
                .cornerRadius(10)
            }

            if request.status.lowercased() == "rejected" {
                Button {
                    Task {
                        await viewModel.reorderRequest(request: request)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Re-Order Product")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(BoutiqueTheme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .padding(.top, 4)
            }

            if let shipment = shipment {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "truck.box")
                            .foregroundColor(BoutiqueTheme.primary)
                        Text(shipment.carrier ?? "Standard Carrier")
                            .font(.subheadline.bold())
                        Spacer()
                        if let tracking = shipment.trackingNumber {
                            Text(tracking)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(BoutiqueTheme.textSecondary)
                        }
                    }

                    if let eta = shipment.estimatedDelivery {
                        Text("ETA: \(eta)")
                            .font(.caption)
                            .foregroundColor(BoutiqueTheme.textSecondary)
                    }

                    if let issue = issueCondition {
                        // Issue detected — IM is resolving it
                        HStack(spacing: 8) {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Issue Under Review")
                                    .font(.caption.bold())
                                    .foregroundColor(.orange)
                                Text(issue == .damaged
                                     ? "Replacement being arranged by warehouse."
                                     : "Partial delivery noted. Replacement in process.")
                                    .font(.caption2)
                                    .foregroundColor(BoutiqueTheme.textSecondary)
                            }
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    } else if hasGRN, let grn = existingGRN, grn.condition == .good {
                        // Good GRN confirmed
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Received: \(grn.grnNumber ?? "")")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if shipment.hasGRN == true && issueCondition == nil {
                        // has_grn flag set but no local GRN record (cross-role RLS) — show delivered
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Goods Received")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                        }
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    } else if shipment.status == "in_transit" {
                        Button {
                            shipmentForGRN = shipment
                        } label: {
                            Text("Receive Goods")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(BoutiqueTheme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
        .padding(16)
        .boutiqueCardChrome()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(BoutiqueTheme.border)
            Text("No \(segments[selectedSegment]) Requests")
                .font(.headline)
                .foregroundColor(BoutiqueTheme.textPrimary)
            Spacer()
        }
    }

    private func shipmentStatusChip(_ status: String) -> some View {
        let (color, label, icon): (Color, String, String) = {
            switch status {
            case "in_transit":  return (.blue, "In Transit", "shippingbox.fill")
            case "delivered":   return (.green, "Delivered", "checkmark.circle.fill")
            case "pending":     return (.orange, "Pending", "clock.fill")
            default:            return (.gray, status.capitalized, "circle.fill")
            }
        }()
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(label)
        }
        .font(.caption.bold())
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }

    private func statusChip(_ status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status.lowercased() {
            case "approved": return (.green, "Approved")
            case "rejected": return (BoutiqueTheme.error, "Rejected")
            case "pending": return (.orange, "Order Placed")
            default: return (.gray, status.capitalized)
            }
        }()
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
    
    private func issueChip(_ issueLabel: String) -> some View {
        Text(issueLabel)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.15))
            .foregroundColor(.red)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundColor(BoutiqueTheme.error)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(BoutiqueTheme.textSecondary)
        }
        .padding(40)
    }

    @ViewBuilder
    private func grnBanner(grnNumber: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRN Generated!")
                        .font(.subheadline.bold())
                    Text(grnNumber)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(BoutiqueTheme.primary)
                }
                Spacer()
                Button { withAnimation { showGRNBanner = false } } label: {
                    Image(systemName: "xmark").foregroundColor(BoutiqueTheme.textSecondary)
                }
            }
            .padding(16)
            .background(BoutiqueTheme.card)
            .cornerRadius(16)
            .shadow(radius: 8)
            .padding(16)
        }
    }
}

struct ShipmentSegmentedControl: View {
    @Binding var selected: Int
    let segments: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<segments.count, id: \.self) { index in
                Button(action: { withAnimation { selected = index } }) {
                    Text(segments[index])
                        .font(.system(size: 13, weight: selected == index ? .semibold : .medium))
                        .foregroundColor(selected == index ? .white : BoutiqueTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selected == index ? BoutiqueTheme.primary : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(BoutiqueTheme.surface)
        .clipShape(Capsule())
    }
}
