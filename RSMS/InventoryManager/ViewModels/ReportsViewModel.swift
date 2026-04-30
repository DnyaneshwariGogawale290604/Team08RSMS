import Foundation
import Combine
import SwiftUI

@MainActor
public class ReportsViewModel: ObservableObject {
    @Published public var inventoryItems: [InventoryItem] = []
    @Published public var auditLogs: [AuditLog] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil

    private var cancellables = Set<AnyCancellable>()

    private var syncTimer: Timer?
    
    public init() {
        // Refresh whenever an exception is resolved OR any inventory data changes (scans, GRN, transfers)
        let exceptionResolved = NotificationCenter.default.publisher(for: NSNotification.Name("ExceptionResolved"))
        let dataChanged = NotificationCenter.default.publisher(for: .inventoryManagerDataDidChange)
        
        Publishers.Merge(exceptionResolved, dataChanged)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.fetchData() }
            }
            .store(in: &cancellables)
            
        startAutoSync()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    private func startAutoSync() {
        // Automatically refresh every 45 seconds (reports are less time-critical than items)
        syncTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                await self?.fetchData()
            }
        }
    }

    public func fetchData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let itemsTask = DataService.shared.fetchInventoryItems()
            async let logsTask  = DataService.shared.fetchAllAuditLogs()
            let (items, logs) = try await (itemsTask, logsTask)
            self.inventoryItems = items
            self.auditLogs      = logs
            
            // Inject certification exceptions
            let certIssues = ExceptionEngine.shared.detectCertificationIssues(items: items)
            ExceptionEngine.shared.injectTimeBasedExceptions(certIssues)
        } catch {

            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // ─── Shrink Overview ────────────────────────────────────────────────────────

    public var totalItemsCount: Int { inventoryItems.count }

    public var scrappedCount: Int {
        inventoryItems.filter { $0.status == .scrapped }.count
    }

    public var confirmedMissingCount: Int {
        inventoryItems.filter { $0.isFlaggedMissing }.count
    }

    public var lostItemsCount: Int { scrappedCount + confirmedMissingCount }

    public var lostItems: [InventoryItem] {
        inventoryItems.filter { $0.status == .scrapped || $0.isFlaggedMissing }
    }

    public var shrinkPercentage: Double {
        guard totalItemsCount > 0 else { return 0 }
        return Double(lostItemsCount) / Double(totalItemsCount) * 100
    }

    public var underRepairCount: Int {
        inventoryItems.filter { $0.status == .underRepair }.count
    }

    public var underRepairItems: [InventoryItem] {
        inventoryItems.filter { $0.status == .underRepair }
    }

    /// Items previously flagged missing that were found again (scanned with "Found" metadata)
    public var recoveredCount: Int {
        auditLogs.filter {
            $0.action == .scanned &&
            ($0.metadata?.lowercased().contains("found") == true)
        }.count
    }

    public var recoveredItems: [InventoryItem] {
        let recoveredIds = Set(auditLogs.filter {
            $0.action == .scanned &&
            ($0.metadata?.lowercased().contains("found") == true)
        }.map { $0.itemId })
        return inventoryItems.filter { recoveredIds.contains($0.id) }
    }

    // ─── Shrink Trend (last 30 days, capped to 7 shown data points) ─────────────

    public struct TrendPoint: Identifiable {
        public let id   = UUID()
        public let date : Date
        public let count: Int
    }

    public var shrinkTrendData: [TrendPoint] {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())

        // Build zeroed 7-day window
        var buckets: [Date: Int] = [:]
        for offset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            buckets[day] = 0
        }

        // Fill from audit logs (flaggedMissing or scrapped status changes)
        let lossLogs = auditLogs.filter {
            $0.action == .flaggedMissing ||
            ($0.action == .statusChanged && $0.metadata?.lowercased().contains("scrap") == true)
        }
        for log in lossLogs {
            let day = calendar.startOfDay(for: log.timestamp)
            if buckets[day] != nil { buckets[day]! += 1 }
        }

        return buckets.keys.sorted().map { TrendPoint(date: $0, count: buckets[$0]!) }
    }

    public var totalShrinkLast7Days: Int { shrinkTrendData.reduce(0) { $0 + $1.count } }

    // ─── Category-wise Shrink ────────────────────────────────────────────────────

    public struct CategoryShrink: Identifiable {
        public let id       = UUID()
        public let category : String
        public let count    : Int
    }

    public var categoryShrinkData: [CategoryShrink] {
        let lost = inventoryItems.filter { $0.status == .scrapped || $0.isFlaggedMissing }
        let grouped = Dictionary(grouping: lost, by: { $0.category.isEmpty ? "Uncategorised" : $0.category })
        return grouped
            .map { CategoryShrink(category: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    // ─── Variance Report ─────────────────────────────────────────────────────────

    /// All non-scrapped, non-sold items are "expected" to be findable
    public var expectedCount: Int {
        inventoryItems.filter {
            $0.status == .available || $0.status == .inTransit ||
            $0.status == .reserved  || $0.status == .underRepair
        }.count
    }

    /// Items confirmed scanned within their SLA window
    public var actualScannedCount: Int {
        inventoryItems.filter { $0.scanStatus == .ok || $0.scanStatus == .dueSoon }.count
    }

    public var varianceCount: Int { expectedCount - actualScannedCount }

    // ─── Scan Compliance ─────────────────────────────────────────────────────────

    public var compliantCount: Int {
        inventoryItems.filter { $0.scanStatus == .ok || $0.scanStatus == .dueSoon }.count
    }

    public var overdueCount: Int {
        inventoryItems.filter { $0.scanStatus == .overdue }.count
    }

    public var compliancePercentage: Double {
        let total = compliantCount + overdueCount
        guard total > 0 else { return 100 }
        return Double(compliantCount) / Double(total) * 100
    }

    // ─── Certification Compliance ──────────────────────────────────────────────

    public var verifiedCount: Int {
        inventoryItems.filter { $0.authenticityStatus == .verified }.count
    }

    public var certPendingCount: Int {
        inventoryItems.filter { $0.authenticityStatus == .pending }.count
    }

    public var certFailedCount: Int {
        inventoryItems.filter { $0.authenticityStatus == .failed }.count
    }

    public var certCompliancePercentage: Double {
        guard totalItemsCount > 0 else { return 100 }
        return Double(verifiedCount) / Double(totalItemsCount) * 100
    }


    // ─── Health Score (composite) ────────────────────────────────────────────────

    /// 0–100 score blending shrink %, scan compliance, and variance
    public var healthScore: Int {
        guard totalItemsCount > 0 else { return 100 }
        let shrinkPenalty     = shrinkPercentage                               // 0–100
        let compliancePenalty = 100 - compliancePercentage                     // 0–100
        let variancePenalty   = min(100, Double(abs(varianceCount)) / Double(max(1, expectedCount)) * 100)
        let raw = 100 - ((shrinkPenalty * 0.5) + (compliancePenalty * 0.3) + (variancePenalty * 0.2))
        return max(0, min(100, Int(raw.rounded())))
    }

    public var healthLabel: String {
        switch healthScore {
        case 85...: return "Excellent"
        case 65..<85: return "Good"
        case 40..<65: return "Fair"
        default: return "Critical"
        }
    }

    public var healthColor: Color {
        switch healthScore {
        case 85...: return .green
        case 65..<85: return Color.appAccent
        case 40..<65: return .orange
        default: return .red
        }
    }
}
