import SwiftUI

/// Boutique Manager's view for all incoming shipments and their GRN status.
public struct ShipmentTrackingView: View {
    @StateObject private var viewModel = BoutiqueShipmentViewModel()
    @State private var shipmentForGRN: Shipment? = nil
    @State private var lastGRN: String? = nil
    @State private var showGRNBanner = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if viewModel.isLoading && viewModel.incomingShipments.isEmpty {
                LoadingView(message: "Loading shipments...")
            } else if let err = viewModel.errorMessage {
                errorView(message: err)
            } else if viewModel.incomingShipments.isEmpty {
                emptyView
            } else {
                shipmentsList
            }

            // GRN Banner
            if showGRNBanner, let grn = lastGRN {
                grnBanner(grnNumber: grn)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Incoming Shipments")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadAll() }
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

    // MARK: - Sub-views

    private var shipmentsList: some View {
        List {
            ForEach(viewModel.incomingShipments) { shipment in
                shipmentCard(for: shipment)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func shipmentCard(for shipment: Shipment) -> some View {
        let existingGRN = viewModel.grn(forShipment: shipment)
        let hasGRN = existingGRN != nil

        ReusableCardView {
            VStack(alignment: .leading, spacing: 12) {

                // Header: ASN + Status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let asn = shipment.asnNumber {
                            Text(asn)
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.appAccent)
                        } else {
                            Text("SHP-\(shipment.id.uuidString.prefix(6).uppercased())")
                                .font(.caption.bold())
                                .foregroundColor(.appAccent)
                        }
                        Text(shipment.request?.product?.name ?? "Shipment")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                    }
                    Spacer()
                    statusChip(shipment.status)
                }

                // Carrier & Tracking
                if let carrier = shipment.carrier {
                    HStack(spacing: 6) {
                        Image(systemName: "shippingbox")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        Text(carrier)
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                        if let tracking = shipment.trackingNumber {
                            Text("· \(tracking)")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                }

                // ETA
                if let eta = shipment.estimatedDelivery {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        Text("Est. Delivery: \(eta)")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                }

                // Quantity
                if let req = shipment.request {
                    HStack(spacing: 6) {
                        Image(systemName: "cube.box")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        Text("\(req.requestedQuantity) units ordered")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                }

                Divider()

                // GRN Status or Receive Button
                if hasGRN, let grn = existingGRN {
                    // GRN already created
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GRN Generated")
                                .font(.caption.bold())
                                .foregroundColor(.green)
                            Text(grn.grnNumber ?? "")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.appSecondaryText)
                        }
                        Spacer()
                        conditionBadge(grn.condition)
                    }
                    .padding(10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(10)

                } else if shipment.status == "in_transit" {
                    // Ready to receive
                    Button {
                        shipmentForGRN = shipment
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Text("Receive Goods & Generate GRN")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                } else if shipment.status == "delivered" && !hasGRN {
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.caption)
                        Text("Delivered — GRN pending")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
        }
    }

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.appSecondaryText)
        }
        .padding(40)
    }

    private var emptyView: some View {
        EmptyStateView(
            icon: "shippingbox",
            title: "No Shipments",
            message: "No incoming shipments for your store yet."
        )
    }

    private func statusChip(_ status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status {
            case "in_transit": return (.blue, "In Transit")
            case "delivered": return (.green, "Delivered")
            case "pending": return (.orange, "Pending")
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

    private func conditionBadge(_ condition: GoodsReceivedNote.GRNCondition) -> some View {
        let (color, label): (Color, String) = {
            switch condition {
            case .good: return (.green, "Good")
            case .damaged: return (.red, "Damaged")
            case .partial: return (.orange, "Partial")
            }
        }()
        return Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func grnBanner(grnNumber: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRN Generated Successfully!")
                        .font(.subheadline.bold())
                        .foregroundColor(.appPrimaryText)
                    Text(grnNumber)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(.appAccent)
                }
                Spacer()
                Button { withAnimation { showGRNBanner = false } } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
            }
            .padding(16)
            .background(Color.appCard)
            .cornerRadius(16)
            .shadow(radius: 12)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}
