# Food Notes Engine Architecture (Race-Free Rewrite)

## Status

Proposed architecture for a full replacement of the current owner-coupled `FoodNotesStore` mutation flow.

Current baseline assumption: commit `a58e204` has been reverted, so onboarding no longer uses the
`onAppear` owner-key initialization workaround.

## Problem Statement

The current model relies on shared mutable state (`onboardingStore.preferences`) plus an implicit global owner pointer. This creates race-prone behavior when:

- async load completes while edits are in progress,
- selected member changes between user intent and async save execution,
- local state is preserved/restored without explicit dirty semantics,
- multiple owners are edited while fetch/sync is in-flight.

This doc defines a full redesign with explicit ownership, single-writer concurrency, and deterministic sync behavior.

## Goals

- Eliminate silent data loss and cross-owner data bleed.
- Make race conditions structurally impossible for known edit/load/switch interleavings.
- Keep UI responsive with optimistic updates.
- Make sync conflict handling deterministic and testable.
- Centralize all business logic in one concurrency boundary.

## Non-Goals

- Preserve existing internal method shapes in `FoodNotesStore`.
- Continue using `.onChange(of: store.preferences)` as the primary mutation trigger.
- Maintain backward compatibility with implicit owner-based mutations.

## Design Principles

- Single writer: one actor owns all mutable food-notes domain state.
- Explicit intent: every mutation includes owner key and operation id.
- Deterministic replay: local pending edits are replayable over fresh server state.
- Derived views: UI state is a projection from actor state, never a second source of truth.
- Idempotent sync: retries and duplicates cannot corrupt state.

## Canonical Components

1. `FoodNotesEngine` (`actor`)
- Owns all mutable domain state.
- Accepts read/write commands.
- Handles load, mutation, debounce, sync, conflict resolution.

2. `FoodNotesViewModel` (`@MainActor`)
- Thin UI adapter.
- Subscribes to engine snapshots and publishes view state.
- Routes UI intents to engine commands.

3. `WebService` gateway
- Existing network layer.
- No business decisions about merge/conflict semantics.

## Canonical Data Model

```swift
typealias OwnerKey = String // "Everyone" or member UUID lowercase

struct EngineState {
    var owners: [OwnerKey: OwnerState]
    var activeOwner: OwnerKey
    var syncQueue: Set<OwnerKey>
    var lastLoadRevision: UInt64
}

struct OwnerState {
    var base: Preferences            // last acknowledged server snapshot
    var working: Preferences         // currently visible local view
    var pendingOps: [PreferenceOp]   // ordered local ops not yet acknowledged
    var version: Int                 // server optimistic concurrency version
    var miscNotes: [String]
    var lastMutationRevision: UInt64
}

struct PreferenceOp: Identifiable, Hashable, Codable {
    var id: UUID
    var ownerKey: OwnerKey
    var kind: OpKind
    var timestampMs: Int64
}

enum OpKind: Hashable, Codable {
    case setList(section: String, values: [String])
    case toggleListItem(section: String, item: String, selected: Bool)
    case setNested(section: String, group: String, values: [String])
    case clearSection(section: String)
    case setMiscNotes([String])
}
```

## Invariants (Must Hold at All Times)

1. `working == replay(base, pendingOps)` for each owner.
2. No op is accepted without explicit `ownerKey`.
3. Owner switching does not mutate any preferences.
4. `pendingOps` order is stable and append-only until ack/rebase.
5. Sync uses `base + pendingOps`; never raw UI snapshots from a shared global struct.
6. Server ack advances `version` exactly once per acknowledged write.
7. Engine is the only writer of `owners`, `activeOwner`, versions, and pending ops.

## Engine API Contract

```swift
actor FoodNotesEngine {
    // Bootstrapping
    func bootstrap(family: Family?, selectedOwner: OwnerKey?) async
    func refreshFromServer() async

    // Reads
    func snapshot() -> FoodNotesSnapshot
    func snapshot(for ownerKey: OwnerKey) -> OwnerSnapshot

    // Ownership
    func setActiveOwner(_ ownerKey: OwnerKey)

    // Mutations (intent-driven)
    func apply(_ op: PreferenceOp)
    func apply(ownerKey: OwnerKey, kind: OpKind)

    // Sync lifecycle
    func flushNow(ownerKey: OwnerKey?) async
    func retryFailed(ownerKey: OwnerKey) async
}
```

All mutation APIs are explicit. No implicit active-owner write API should exist.

## Load / Refresh Algorithm

1. Fetch all food notes from backend (`Everyone` + member notes).
2. Convert server payload into `base` states for each owner.
3. For each owner:
- keep existing `pendingOps`,
- recompute `working = replay(newBase, pendingOps)`,
- preserve local edits without replacing `working` from stale shared UI state.
4. Recompute derived projection (canvas union + item-member associations).
5. Publish new snapshot.

No “preserve current owner only” behavior is allowed.

## Mutation Algorithm

1. Validate owner key and normalize casing.
2. Create op id and append to `pendingOps` for owner.
3. Recompute owner `working = replay(base, pendingOps)`.
4. Recompute derived global projection incrementally (or full rebuild for correctness-first baseline).
5. Schedule owner-specific debounced sync task keyed by owner and token.
6. Publish snapshot.

Owner switch is irrelevant to mutation correctness because owner is explicit in op.

## Sync Algorithm

For each owner in sync queue:

1. Build payload from `working` (which equals `replay(base, pendingOps)`).
2. Send update with current `version`.
3. On success:
- update `version`,
- set `base = working`,
- clear acknowledged `pendingOps`,
- keep `working` unchanged,
- publish snapshot.
4. On version mismatch:
- fetch latest server note for that owner (or all-notes refresh),
- set `base` to server state/version,
- replay pending ops,
- retry with bounded retry policy and backoff.
5. On transient network failure:
- keep `pendingOps`,
- mark owner as unsynced,
- retry with exponential backoff and jitter.

## Conflict Resolution Policy

- Policy: local pending ops win over stale server snapshot because they represent user’s latest intent.
- Mechanism: rebase by replaying `pendingOps` on top of fresh server `base`.
- Duplicate protection: op IDs can be sent in metadata if server supports it. If not, client-side dedupe still applies by ack semantics and one-shot dequeue.

## Migration Rules (Legacy Data)

- Single-member `Everyone -> self` migration runs once in engine bootstrap.
- Migration is data-transform, not a view concern.
- Migration output is written through normal owner state, then synced.
- Migration must be idempotent (safe to rerun after app restart).

## UI Integration Contract

Views must:

1. Bind displayed preferences from `FoodNotesSnapshot.activeOwnerPreferences`.
2. Dispatch intent operations directly:
- chip tap -> `toggleListItem`
- multi-select edits -> `setList` / `setNested`
- misc notes changes -> `setMiscNotes`
3. Stop writing directly to shared `onboardingStore.preferences` as source of truth.
4. Stop using `.onChange(of: preferences)` to infer and persist state.

`Onboarding` can remain as navigation/progress state, but preference truth moves to engine snapshots.

## Hard-Cutover Implementation Plan

This is a single architecture replacement, not a sequence of tactical race patches.

1. Add new domain files:
- `IngrediCheck/Store/FoodNotesEngine.swift`
- `IngrediCheck/Store/FoodNotesTypes.swift` (ops, snapshots, owner state types)
- `IngrediCheck/Store/FoodNotesViewModel.swift`

2. Rewire all food notes mutation entry points to engine intent APIs:
- onboarding canvas
- editable canvas
- unified canvas
- edit sheet interactions

3. Replace old store write methods with compile-time unavailable stubs (temporary) to force callsite migration:
- `preparePreferencesForMember`
- `handleLocalPreferenceChange`
- `applyLocalPreferencesOptimistic`
- `updateFoodNotes` no-op path

4. Move load/refresh/migration orchestration from views into engine bootstrap.

5. Remove owner-pointer dependent state and logic from `FoodNotesStore`.

6. Keep a small compatibility bridge only for read-only rendering while views are rewired in the same rewrite branch.

7. Delete compatibility bridge once all callsites compile against engine snapshots.

## Verification and Test Plan (Required)

### Unit Tests (Actor-Level)

- deterministic replay tests for each `OpKind`,
- owner isolation tests (edit owner A never mutates owner B),
- load-while-edit tests (pending ops survive refresh),
- conflict rebase tests (version mismatch + replay),
- debounce token tests (stale sync task cannot commit),
- idempotency tests (duplicate apply/flush attempts).

### Property / Fuzz Tests

- randomized interleavings of:
  - owner switches,
  - local ops,
  - refresh completion,
  - sync success/failure/mismatch.
- assert invariants after each step.

### Integration Tests

- first tap during initial load is persisted,
- rapid member switching while editing does not drop selections,
- offline edits are replayed and synced after reconnect,
- app relaunch with pending edits preserves and flushes correctly.

### Runtime Guards

- debug-only invariant checks after each mutation/sync transition,
- structured logging with op ids, owner keys, versions, and transition reason.

## Operational Observability

- Metrics:
  - pending ops count per owner,
  - sync latency per owner,
  - version mismatch frequency,
  - retries and terminal failures.
- Logs:
  - `op_applied`, `sync_scheduled`, `sync_started`, `sync_succeeded`, `sync_rebased`, `sync_failed`.

## Risks and Mitigations

- Risk: full rewrite complexity.
  - Mitigation: strict API contract + invariant-heavy test suite before merge.

- Risk: UI regression from new binding path.
  - Mitigation: adapter layer with snapshot parity assertions during transition branch.

- Risk: server semantics mismatch for conflict handling.
  - Mitigation: explicit contract test cases against staging endpoints.

## Acceptance Criteria

- No mutable global owner pointer in write path.
- All writes are explicit owner-scoped ops.
- `working == replay(base, pendingOps)` invariant enforced.
- All race-focused tests pass.
- Manual QA validates no silent drops or cross-owner contamination.
