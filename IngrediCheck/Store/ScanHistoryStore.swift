import SwiftUI

/// Centralized store for managing scan history across the app
/// Provides single source of truth for scan data, caching, and barcode mapping
@Observable final class ScanHistoryStore {

    // MARK: - Public State

    /// All loaded scans (ordered by most recent first)
    @MainActor private(set) var scans: [DTO.Scan] = []

    /// Cache of scans by scanId for quick lookup
    @MainActor private(set) var scanCache: [String: DTO.Scan] = [:]

    /// Map of barcode -> scanId for quick barcode lookups
    @MainActor private(set) var barcodeToScanIdMap: [String: String] = [:]

    /// Loading state
    @MainActor private(set) var isLoading: Bool = false

    /// Last fetch error (if any)
    @MainActor private(set) var lastError: Error?

    /// Whether there are more scans to load
    @MainActor private(set) var hasMore: Bool = true

    /// Whether the initial load (offset=0) has completed successfully
    @MainActor private(set) var hasLoaded: Bool = false

    /// In-flight history request so concurrent callers can await shared work.
    @MainActor private var activeLoadTask: Task<Void, Never>?
    
    // MARK: - Dependencies

    private let webService: WebService

    // MARK: - Init

    init(webService: WebService) {
        self.webService = webService
    }

    // MARK: - Public Methods
    
    /// Load next page of history if available
    @MainActor
    func loadMore() async {
        guard hasMore && !isLoading else { return }
        await loadHistory(limit: 20, offset: scans.count)
    }

    /// Load scan history from API
    /// - Parameters:
    ///   - limit: Maximum number of scans to fetch
    ///   - offset: Offset for pagination
    ///   - forceRefresh: If true, bypasses loading state check
    @MainActor
    func loadHistory(limit: Int = 20, offset: Int = 0, forceRefresh: Bool = false) async {
        Log.debug("ScanHistoryStore", "🔵 loadHistory called - limit: \(limit), offset: \(offset), forceRefresh: \(forceRefresh)")

        if let existingTask = activeLoadTask {
            if !forceRefresh {
                Log.debug("ScanHistoryStore", "⏸️ Awaiting in-flight history request")
                await existingTask.value
                return
            }
            await existingTask.value
        }

        guard forceRefresh || (!isLoading && !(offset == 0 && hasLoaded)) else {
            Log.debug("ScanHistoryStore", "⏸️ Already loading or loaded, skipping")
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            lastError = nil
            defer {
                isLoading = false
                activeLoadTask = nil
            }

            Log.debug("ScanHistoryStore", "🔵 Loading scan history - limit: \(limit), offset: \(offset)")

            do {
                let response = try await webService.fetchScanHistory(limit: limit, offset: offset)

                // Check if we reached the end
                hasMore = response.scans.count >= limit

                // Update scans array
                if offset == 0 {
                    // Fresh load - replace all scans
                    scans = response.scans
                    Log.debug("ScanHistoryStore", "✅ Loaded \(response.scans.count) scans (fresh)")
                } else {
                    // Pagination - append new scans (filtering duplicates just in case)
                    let newScans = response.scans.filter { newScan in
                        !scans.contains(where: { $0.id == newScan.id })
                    }
                    scans.append(contentsOf: newScans)
                    Log.debug("ScanHistoryStore", "✅ Loaded \(newScans.count) new scans (pagination)")
                }

                // Update caches
                for scan in response.scans {
                    scanCache[scan.id] = scan

                    // Map barcode to scanId for quick lookups
                    if let barcode = scan.barcode, !barcode.isEmpty {
                        barcodeToScanIdMap[barcode] = scan.id
                    }
                }

                Log.debug("ScanHistoryStore", "💾 Cache updated - total scans: \(scans.count), cache size: \(scanCache.count), barcode mappings: \(barcodeToScanIdMap.count)")

                if offset == 0 { hasLoaded = true }

            } catch {
                Log.debug("ScanHistoryStore", "❌ Failed to load scan history - error: \(error.localizedDescription)")
                lastError = error
            }
        }
        activeLoadTask = task
        await task.value
    }

    /// Ensures the first page has loaded, retrying a bounded number of times.
    @MainActor
    func loadInitialHistoryIfNeeded(limit: Int = 20, retryCount: Int = 1) async {
        let boundedRetryCount = max(0, retryCount)
        for attempt in 0...boundedRetryCount {
            await loadHistory(limit: limit, offset: 0)
            if hasLoaded { return }
            if attempt < boundedRetryCount {
                Log.debug("ScanHistoryStore", "🔁 Initial history load failed, retrying once")
            }
        }
    }

    /// Get a scan by ID from cache
    /// - Parameter id: The scan ID
    /// - Returns: The cached scan, or nil if not found
    @MainActor
    func getScan(id: String) -> DTO.Scan? {
        return scanCache[id]
    }

    /// Get a scan by barcode from cache
    /// - Parameter barcode: The barcode string
    /// - Returns: The cached scan, or nil if not found
    @MainActor
    func getScanByBarcode(_ barcode: String) -> DTO.Scan? {
        guard let scanId = barcodeToScanIdMap[barcode] else { return nil }
        return scanCache[scanId]
    }

    /// Add or update a scan in the store (e.g., from real-time updates)
    /// - Parameter scan: The scan to add/update
    @MainActor
    func upsertScan(_ scan: DTO.Scan) {
        Log.debug("ScanHistoryStore", "🔄 Upserting scan - scanId: \(scan.id)")

        // Update or add to scans array
        if let existingIndex = scans.firstIndex(where: { $0.id == scan.id }) {
            scans[existingIndex] = scan
            Log.debug("ScanHistoryStore", "✅ Updated existing scan at index \(existingIndex)")
        } else {
            scans.insert(scan, at: 0)  // Add to front (most recent)
            Log.debug("ScanHistoryStore", "✅ Added new scan to front")
        }

        // Update cache
        scanCache[scan.id] = scan

        // Update barcode mapping
        if let barcode = scan.barcode, !barcode.isEmpty {
            barcodeToScanIdMap[barcode] = scan.id
        }
    }

    /// Update an existing scan's favorite status
    /// - Parameters:
    ///   - scanId: The scan ID
    ///   - isFavorited: New favorite status
    @MainActor
    func updateFavoriteStatus(scanId: String, isFavorited: Bool) {
        Log.debug("ScanHistoryStore", "⭐️ Updating favorite status - scanId: \(scanId), isFavorited: \(isFavorited)")

        // Update in scans array
        if let index = scans.firstIndex(where: { $0.id == scanId }) {
            let existingScan = scans[index]
            let updatedScan = DTO.Scan(
                id: existingScan.id,
                scan_type: existingScan.scan_type,
                barcode: existingScan.barcode,
                state: existingScan.state,
                product_info: existingScan.product_info,
                product_info_source: existingScan.product_info_source,
                analysis_result: existingScan.analysis_result,
                images: existingScan.images,
                latest_guidance: existingScan.latest_guidance,
                created_at: existingScan.created_at,
                last_activity_at: existingScan.last_activity_at,
                is_favorited: isFavorited,
                analysis_id: existingScan.analysis_id
            )
            scans[index] = updatedScan
            scanCache[scanId] = updatedScan
        }
    }

    /// Remove a scan from the store
    /// - Parameter scanId: The scan ID to remove
    @MainActor
    func removeScan(scanId: String) {
        Log.debug("ScanHistoryStore", "🗑️ Removing scan - scanId: \(scanId)")

        // Remove from scans array
        scans.removeAll { $0.id == scanId }

        // Remove from cache
        if let scan = scanCache[scanId] {
            scanCache.removeValue(forKey: scanId)

            // Remove barcode mapping
            if let barcode = scan.barcode {
                barcodeToScanIdMap.removeValue(forKey: barcode)
            }
        }
    }

    /// Clear all cached data
    @MainActor
    func clearAll() {
        Log.debug("ScanHistoryStore", "🧹 Clearing all data")
        activeLoadTask?.cancel()
        activeLoadTask = nil
        isLoading = false
        scans.removeAll()
        scanCache.removeAll()
        barcodeToScanIdMap.removeAll()
        hasMore = true
        hasLoaded = false
        lastError = nil
    }

    /// Reset store to initial state (used when prefetcher needs a clean slate)
    @MainActor
    func reset() {
        activeLoadTask?.cancel()
        activeLoadTask = nil
        isLoading = false
        scans.removeAll()
        scanCache.removeAll()
        barcodeToScanIdMap.removeAll()
        hasMore = true
        hasLoaded = false
        lastError = nil
    }

    /// Get scans filtered by criteria
    /// - Parameter predicate: Filter predicate
    /// - Returns: Filtered scans
    @MainActor
    func getScans(where predicate: (DTO.Scan) -> Bool) -> [DTO.Scan] {
        return scans.filter(predicate)
    }

    /// Get favorite scans only
    @MainActor
    func getFavoriteScans() -> [DTO.Scan] {
        return scans.filter { $0.is_favorited == true }
    }
}
