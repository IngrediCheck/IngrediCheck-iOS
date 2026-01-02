# Scan API Integration Plan

## Overview

This document outlines the plan to integrate the new Scan API endpoints into the IngrediCheck iOS app, replacing the current `streamUnifiedAnalysis` approach for barcode and photo scanning.

## Branch
- **Branch:** `feature/scan-api-integration`
- **Base Branch:** `develop`

## Current Implementation Analysis

### Current Barcode Scan Flow
**Files:** `BarcodeAnalysisView.swift`, `BarcodeScan/overlay.swift`, `WebService.swift`

1. **Trigger:** User scans barcode → `BarcodeScanAnalysisService` or `BarcodeAnalysisViewModel.analyze()`
2. **API Call:** `WebService.streamUnifiedAnalysis(input: .barcode(barcode), ...)`
3. **Current Endpoint:** `POST /analyze-stream` (Supabase Functions)
4. **SSE Events:** 
   - `product` → `DTO.Product`
   - `analysis` → `[DTO.IngredientRecommendation]`
   - `error` → Error message
5. **Flow:**
   - Client sends barcode in request body
   - Server looks up product (presumably OpenFoodFacts client-side or server-side)
   - Product info received → UI updates
   - Analysis runs inline → Recommendations received
   - Results cached via `BarcodeScanAnalysisService`
   - History refreshed after successful scan

### Current Photo Scan Flow
**Files:** `LabelAnalysisView.swift`, `ImageCaptureView.swift`, `WebService.swift`

1. **Trigger:** User captures images → `ImageCaptureView.capturePhoto()`
2. **Image Processing:**
   - Each image: OCR task, upload to Supabase storage (`productimages` bucket), barcode detection
   - Images stored as `ProductImage` with async tasks
3. **API Call:** `WebService.streamUnifiedAnalysis(input: .productImages(productImages), ...)`
4. **Current Endpoint:** `POST /analyze-stream` (Supabase Functions)
5. **Request Body:** JSON with `ImageInfo[]` containing `imageFileHash`, `imageOCRText`, `barcode`
6. **SSE Events:** Same as barcode scan
7. **Flow:**
   - Images uploaded to Supabase storage first (get hash)
   - All image metadata sent in single request
   - Product info received → UI updates
   - Analysis received → Recommendations displayed

### Current Scan History
**Files:** `WebService.swift`, `Tabs/ListsTab.swift`, `HomeView.swift`

1. **Endpoint:** `GET /history` (Supabase Functions)
2. **Response:** `[DTO.HistoryItem]`
3. **Usage:** Displayed in `RecentScansView`, `RecentScansListView`, `HomeView`
4. **Refresh:** After successful scans, on pull-to-refresh, on app launch

## New API Implementation

### API Base URLs

Based on the documentation:
- **Scan endpoints** (barcode, image, get): `https://ingredicheck-ai.fly.dev/v2/`
- **Scan history**: Default Supabase URL (`Config.supabaseFunctionsURLBase`)

**Note:** `Config.swift` has `flyDevAPIBase` but it has a leading space - needs to be fixed.

### New Endpoints Mapping

| Endpoint | Method | Base URL | Purpose |
|----------|--------|----------|---------|
| `scan/barcode` | POST | fly.dev | Barcode scan (SSE) |
| `scan/{scan_id}/image` | POST | fly.dev | Submit photo for scan |
| `scan/{scan_id}` | GET | fly.dev | Get scan status/result |
| `scan/history` | GET | Supabase | Get scan history |

## Integration Plan

### Phase 1: Configuration & Infrastructure

#### 1.1 Update Config.swift
- [ ] Fix `flyDevAPIBase` (remove leading space)
- [ ] Add helper property `scanAPIBaseURL` for fly.dev endpoints
- [ ] Ensure Supabase base URL is used for scan history

#### 1.2 Update SafeEatsEndpoint Enum
**File:** `SupabaseRequestBuilder.swift`
- [ ] Add `scan_barcode = "scan/barcode"`
- [ ] Add `scan_image = "scan/%@/image"` (with itemId placeholder)
- [ ] Add `scan_get = "scan/%@"` (with itemId placeholder)
- [ ] Add `scan_history = "scan/history"`

#### 1.3 Update SupabaseRequestBuilder
**File:** `SupabaseRequestBuilder.swift`
- [ ] Add support for using fly.dev base URL for scan endpoints
- [ ] Method to determine which base URL to use based on endpoint
- [ ] Ensure existing functionality remains unchanged

### Phase 2: DTO Models

#### 2.1 Add Scan API Models to DTO.swift
**File:** `DTO.swift`

- [ ] `ScanProductInfo` - Product info from scan
- [ ] `ScanImageInfo` - Image info (URL)
- [ ] `ScanAnalysisResult` - Analysis result with overall match
- [ ] `ScanIngredientAnalysis` - Individual ingredient analysis
- [ ] `ScanProductInfoEvent` - SSE event payload for product_info
- [ ] `ScanAnalysisEvent` - SSE event payload for analysis
- [ ] `ScanImage` enum - Inventory vs User image types
- [ ] `Scan` - Full scan object
- [ ] `SubmitImageResponse` - Response from image upload
- [ ] `ScanHistoryResponse` - Paginated history response

**Mapping Considerations:**
- `ScanProductInfo` vs current `DTO.Product` - need adapter/mapper
- `ScanAnalysisResult` vs current `[DTO.IngredientRecommendation]` - different structure
- `overall_match` ("matched", "uncertain", "unmatched") vs `ProductRecommendation` enum

### Phase 3: WebService Methods

#### 3.1 Add Scan Stream Error Type
**File:** `WebService.swift`
- [ ] `ScanStreamError` struct (similar to `UnifiedAnalysisStreamError`)

#### 3.2 Add streamBarcodeScan Method
**File:** `WebService.swift`
- [ ] Implement SSE stream handling for barcode scans
- [ ] Handle events: `product_info`, `analysis`, `error`, `done`
- [ ] Extract `scan_id` from `product_info` event
- [ ] Map `ScanProductInfo` to existing `DTO.Product` for compatibility (or update all views)
- [ ] Map `ScanAnalysisResult` to `[DTO.IngredientRecommendation]` for compatibility
- [ ] Add PostHog analytics tracking (request_id, latency, etc.)

#### 3.3 Add submitScanImage Method
**File:** `WebService.swift`
- [ ] POST to `/scan/{scan_id}/image` with image data
- [ ] Handle response codes: 200, 401, 403, 413 (too large), 400 (max images)
- [ ] Return `SubmitImageResponse`
- [ ] Remove dependency on Supabase storage upload for scan images

#### 3.4 Add getScan Method
**File:** `WebService.swift`
- [ ] GET `/scan/{scan_id}`
- [ ] Handle response codes: 200, 401, 403, 404
- [ ] Return `DTO.Scan`
- [ ] Used for polling photo scan status

#### 3.5 Update fetchScanHistory Method (or create new)
**File:** `WebService.swift`
- [ ] Option A: Replace existing `fetchHistory()` to use new endpoint
- [ ] Option B: Create `fetchScanHistory()` and keep old one for backward compatibility
- [ ] Implement pagination (limit/offset)
- [ ] Map `Scan[]` to `[DTO.HistoryItem]` for UI compatibility
- [ ] Or update UI to use new `Scan` model directly

**Decision Needed:** Should we:
1. Keep old history endpoint for backward compatibility during migration?
2. Replace immediately?
3. Support both and phase out old one?

### Phase 4: Barcode Scan Integration

#### 4.1 Update BarcodeAnalysisView
**File:** `BarcodeAnalysisView.swift`

**Option A: Direct Replacement**
- [ ] Replace `streamUnifiedAnalysis` call with `streamBarcodeScan`
- [ ] Update event handlers to use new callbacks
- [ ] Map `ScanProductInfo` → `DTO.Product` inline
- [ ] Map `ScanAnalysisResult` → `[DTO.IngredientRecommendation]` inline
- [ ] Handle `scan_id` from product_info event
- [ ] Update error handling for new error structure

**Option B: Create Adapter Layer**
- [ ] Create adapter method that wraps new API and converts to old format
- [ ] Views continue using existing interface
- [ ] Easier rollback but more code

**Recommendation:** Option A (direct replacement) for cleaner code

#### 4.2 Update BarcodeScan Overlay
**File:** `BarcodeScan/overlay.swift`
- [ ] Update Task.detached block to use `streamBarcodeScan`
- [ ] Handle new event types (`product_info` instead of `product`)
- [ ] Store `scan_id` for potential photo addition
- [ ] Map new response models to existing cached format
- [ ] Update `BarcodeScanAnalysisService` if needed

#### 4.3 Handle "Add Photo" Flow for Barcode Scans
- [ ] When product not found, allow adding photos
- [ ] Use `scan_id` from error event
- [ ] Call `submitScanImage` for each photo
- [ ] Poll with `getScan` until `status == "idle"`
- [ ] Update UI with new product info/analysis

### Phase 5: Photo Scan Integration

#### 5.1 Update ImageCaptureView
**File:** `ImageCaptureView.swift`

**Major Changes:**
- [ ] **Remove:** Supabase storage upload (`uploadImage`)
- [ ] **Remove:** OCR task (server handles OCR)
- [ ] **Remove:** Barcode detection task (server handles)
- [ ] **Add:** Generate `scan_id` (UUID) when first image is captured
- [ ] **Add:** Call `submitScanImage` for each captured image
- [ ] **Add:** Store `scan_id` in state
- [ ] **Simplified:** `ProductImage` no longer needs async tasks for upload/OCR

**Impact:**
- `ProductImage` struct may need simplification
- Less client-side processing = faster capture flow

#### 5.2 Update LabelAnalysisView
**File:** `LabelAnalysisView.swift`

**Major Changes:**
- [ ] **Remove:** `streamUnifiedAnalysis(input: .productImages(...))` call
- [ ] **Add:** Polling mechanism using `getScan(scanId:)`
- [ ] **Add:** Handle `latest_guidance` from scan response
- [ ] **Add:** Show guidance messages to user
- [ ] **Add:** Handle scan status transitions (processing → idle)
- [ ] **Add:** Map `Scan` → `DTO.Product` and `[DTO.IngredientRecommendation]`

**Flow:**
1. Images submitted via `submitScanImage` (from ImageCaptureView)
2. Start polling `getScan` every 2 seconds
3. Show `latest_guidance` if available
4. When `status == "idle"` and `analysis_status == "complete"`, stop polling
5. Display results similar to current flow

#### 5.3 Handle Multiple Image Submission
- [ ] Allow submitting multiple images without waiting
- [ ] Track submission status for each image
- [ ] Handle queue position feedback
- [ ] Show progress indicator

### Phase 6: Scan History Integration

#### 6.1 Update History Fetching
**Files:** `WebService.swift`, `Tabs/ListsTab.swift`, `HomeView.swift`, `LoggedInRootView.swift`

**Decision Point:** Map new `Scan[]` to existing `HistoryItem[]` or update UI?

**Option A: Map to Existing Format**
- [ ] Create mapper: `Scan` → `HistoryItem`
- [ ] Update `fetchHistory()` to use new endpoint
- [ ] UI code remains unchanged
- [ ] Easier migration, but loses new data (images, scan_type, etc.)

**Option B: Update UI to Use New Format**
- [ ] Update `HistoryItem` or create new view model
- [ ] Update all views that display history
- [ ] More work but leverages new API fully

**Recommendation:** Option B for long-term, but Option A for incremental migration

#### 6.2 Update RecentScans Views
- [ ] Update `RecentScansListView` to handle new data structure
- [ ] Update `HomeRecentScanRow` if data model changes
- [ ] Handle pagination if needed
- [ ] Display scan images if available

### Phase 7: Data Model Mapping & Compatibility

#### 7.1 Product Info Mapping
**Challenge:** `ScanProductInfo` vs `DTO.Product`

**Differences:**
- `ScanProductInfo.images: [ScanImageInfo]?` vs `DTO.Product.images: [ImageLocationInfo]`
- `ScanImageInfo.url: String?` vs `ImageLocationInfo` (url or imageFileHash)

**Solution:**
- Create extension/mapper: `ScanProductInfo.toProduct() -> DTO.Product`
- Handle image URL conversion
- Default to empty images if conversion fails

#### 7.2 Analysis Result Mapping
**Challenge:** `ScanAnalysisResult` vs `[DTO.IngredientRecommendation]`

**Differences:**
- New format has `overall_analysis`, `overall_match`, `ingredient_analysis[]`
- Old format is flat array of recommendations
- `match` values: "matched"/"uncertain"/"unmatched" vs "MaybeUnsafe"/"DefinitelyUnsafe"/"Safe"

**Solution:**
- Create mapper: `ScanAnalysisResult.toIngredientRecommendations() -> [DTO.IngredientRecommendation]`
- Map `match: "unmatched"` → `SafetyRecommendation.definitelyUnsafe`
- Map `match: "uncertain"` → `SafetyRecommendation.maybeUnsafe`
- Use `ingredient_analysis[].reasoning` for `reasoning` field
- Use `ingredient_analysis[].members_affected` for context

#### 7.3 Match Status Mapping
**Challenge:** `overall_match: String` vs `ProductRecommendation` enum

**Values:**
- "matched" → `.match`
- "uncertain" → `.needsReview`
- "unmatched" → `.notMatch`

**Solution:**
- Create helper: `String.toProductRecommendation() -> ProductRecommendation?`

### Phase 8: Error Handling & Edge Cases

#### 8.1 Barcode Scan Errors
- [ ] Handle "product not found" error (includes scan_id)
- [ ] Handle network errors
- [ ] Handle timeout errors (60s timeout)
- [ ] Handle invalid barcode format

#### 8.2 Photo Scan Errors
- [ ] Handle image too large (413)
- [ ] Handle max images reached (400)
- [ ] Handle scan not found (404)
- [ ] Handle unauthorized (401/403)
- [ ] Handle polling timeout
- [ ] Handle image upload failures

#### 8.3 Scan History Errors
- [ ] Handle pagination edge cases
- [ ] Handle empty history
- [ ] Handle network failures
- [ ] Handle invalid response format

### Phase 9: Testing Strategy

#### 9.1 Unit Tests
- [ ] Test DTO decoding for all new models
- [ ] Test mapping functions (ScanProductInfo → Product, etc.)
- [ ] Test error handling

#### 9.2 Integration Tests
- [ ] Test barcode scan flow end-to-end
- [ ] Test photo scan flow end-to-end
- [ ] Test scan history fetching
- [ ] Test error scenarios

#### 9.3 Manual Testing
- [ ] Known barcode: `3017620422003` (Nutella)
- [ ] Unknown barcode: `0000000000000`
- [ ] Photo scan with 1 image
- [ ] Photo scan with multiple images (up to 20)
- [ ] Photo scan with large image (>10MB) - should error
- [ ] Photo scan with 21 images - should error on 21st
- [ ] Scan history pagination
- [ ] Adding photos to barcode scan when product not found

### Phase 10: Migration & Rollout

#### 10.1 Feature Flag (Optional)
- [ ] Add feature flag to toggle between old/new API
- [ ] Allows gradual rollout
- [ ] Easier rollback if issues found

#### 10.2 Backward Compatibility
- [ ] Decide if old `streamUnifiedAnalysis` should remain
- [ ] Or remove after migration complete
- [ ] Update all call sites

#### 10.3 Cleanup
- [ ] Remove old `uploadImage` for scan images (keep for feedback?)
- [ ] Remove OCR/barcode detection from ImageCaptureView
- [ ] Remove old history endpoint usage
- [ ] Update documentation

## Implementation Order (Recommended)

1. **Phase 1**: Configuration & Infrastructure (foundation)
2. **Phase 2**: DTO Models (data structures)
3. **Phase 7**: Data Model Mapping (understand conversions early)
4. **Phase 3**: WebService Methods (API layer)
5. **Phase 4**: Barcode Scan Integration (simpler flow first)
6. **Phase 5**: Photo Scan Integration (more complex)
7. **Phase 6**: Scan History Integration
8. **Phase 8**: Error Handling & Edge Cases
9. **Phase 9**: Testing
10. **Phase 10**: Migration & Rollout

## Key Decisions Needed

1. **History Endpoint Migration:**
   - Replace immediately or support both?
   - Map to existing format or update UI?

2. **Data Model Compatibility:**
   - Create adapters/mappers or update all views to use new models?

3. **Feature Flag:**
   - Use feature flag for gradual rollout?
   - Or direct replacement?

4. **Image Storage:**
   - Remove Supabase storage upload entirely?
   - Or keep for other use cases (feedback images)?

5. **OCR/Barcode Detection:**
   - Remove client-side OCR completely?
   - Keep as fallback?

## Risks & Mitigations

### Risk 1: Breaking Existing Functionality
**Mitigation:** 
- Thorough testing
- Feature flag for gradual rollout
- Keep old code until new code is verified

### Risk 2: Data Model Incompatibilities
**Mitigation:**
- Create comprehensive mapping layer
- Test all edge cases
- Handle missing/null fields gracefully

### Risk 3: Performance Issues
**Mitigation:**
- Monitor API response times
- Optimize polling intervals
- Handle timeouts appropriately

### Risk 4: Missing Features
**Mitigation:**
- Review new API capabilities vs current features
- Ensure all current features are covered
- Document any feature gaps

## Success Criteria

- [ ] Barcode scans work with new API
- [ ] Photo scans work with new API
- [ ] Scan history displays correctly
- [ ] All existing features maintained
- [ ] No regressions in user experience
- [ ] Performance is acceptable or improved
- [ ] Error handling is robust
- [ ] Code is maintainable and well-documented

## Notes

- The new API provides server-side scan persistence, which the old API didn't
- Photo scans now use incremental upload instead of batch
- Analysis runs after product info is found, not inline
- Client generates scan_id for photo scans (UUID)
- Server generates scan_id for barcode scans (returned in event)
- Scan history endpoint uses Supabase URL, others use fly.dev URL
- New API has better error messages and status tracking
