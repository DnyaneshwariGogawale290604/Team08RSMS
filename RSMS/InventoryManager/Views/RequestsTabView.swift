import SwiftUI

public struct RequestsTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @State private var selectedSection: Int = 0 // 0: Incoming (Boutique), 1: Outgoing (Vendor)
    
    public init() {}
    
    public var body: some View {
        NavigationView {
             ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("Requests", selection: $selectedSection) {
                        Text("Incoming (Boutique)").tag(0)
                        Text("Outgoing (Vendor)").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                        Spacer()
                    } else if selectedSection == 0 {
                        incomingRequestsSection()
                    } else {
                        outgoingRequestsSection()
                    }
                }
             }
             .navigationTitle("Requests")
             .navigationBarTitleDisplayMode(.inline)
             .onAppear {
                 Task {
                     await viewModel.loadData()
                 }
             }
        }
    }
    
    @ViewBuilder
    private func incomingRequestsSection() -> some View {
        let incoming = viewModel.pickLists // These are the boutique requests
        if incoming.isEmpty {
            Spacer()
            Text("No incoming requests from boutiques.").foregroundColor(.appSecondaryText)
            Spacer()
        } else {
            List {
                ForEach(incoming) { request in
                    incomingRequestCard(request: request)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
    
    @ViewBuilder
    private func incomingRequestCard(request: ProductRequest) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("REQ-\(request.id.uuidString.prefix(5).uppercased())")
                        .font(.headline).foregroundColor(.appPrimaryText)
                    Spacer()
                    if request.status == "approved" {
                        Text("Approved").font(.caption.bold()).foregroundColor(.green)
                    } else if request.status == "pending" {
                        Text("Pending").font(.caption.bold()).foregroundColor(.orange)
                    } else if request.status == "rejected" {
                        Text("Rejected").font(.caption.bold()).foregroundColor(.red)
                    } else {
                        Text(request.status.capitalized).font(.caption.bold()).foregroundColor(.appSecondaryText)
                    }
                }
                
                Text("From: \(request.store?.name ?? "Unknown Boutique")").font(.subheadline)
                
                Divider()
                
                HStack {
                    Text("\(request.requestedQuantity)x \(request.product?.name ?? "Unknown Product")")
                        .font(.body)
                    Spacer()
                }
                
                Divider()
                
                HStack {
                    if request.status == "rejected" {
                        Text("Rejected: \(request.rejectionReason ?? "No reason given")")
                            .font(.caption).foregroundColor(.red)
                    } else if request.status == "approved" {
                        Button(action: {}) {
                            Text("Shipment In Transit")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(8)
                        }
                    } else {
                        Button(action: {
                            Task { await viewModel.rejectRequest(request: request) }
                        }) {
                            Text("Reject").font(.caption.bold())
                                .foregroundColor(.red)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                        }
                        
                        Button(action: {
                            Task { await viewModel.acceptRequest(request: request) }
                        }) {
                            Text("Accept & Ship")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func outgoingRequestsSection() -> some View {
        let outgoing = viewModel.vendorOrders
        if outgoing.isEmpty {
            Spacer()
            Text("No outgoing vendor requests.").foregroundColor(.appSecondaryText)
            Spacer()
        } else {
            List {
                ForEach(outgoing) { order in
                    ReusableCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("VO-\(order.id.uuidString.prefix(5).uppercased())").font(.headline).foregroundColor(.appPrimaryText)
                                Spacer()
                                if let status = order.status, status == "approved" || status == "delivered" {
                                    Text(status.capitalized).font(.caption.bold()).foregroundColor(.green)
                                } else if let status = order.status {
                                    Text(status.capitalized).font(.caption.bold()).foregroundColor(.orange)
                                } else {
                                    Text("Pending").font(.caption.bold()).foregroundColor(.orange)
                                }
                            }
                            
                            Text("Quantity: \(order.quantity ?? 0) units").font(.subheadline)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await viewModel.loadData()
            }
        }
    }
}
