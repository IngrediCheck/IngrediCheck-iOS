# Food Notes Architecture

## Status

Implemented on the `fix/single-member-edit-sheet-preferences` branch.

This document describes the architecture that replaced the old owner-coupled
`FoodNotesStore` flow after commit `a58e204` was reverted. The current system
does not depend on view lifecycle ordering or a synchronously-set global owner
pointer to avoid onboarding data loss.

## Problem We Removed

The previous design relied on two race-prone ideas:

- one shared mutable `onboardingStore.preferences` value,
- one implicit "current owner" that async work read later.

That made correctness depend on timing:

- load finishing before or after a user edit,
- member switches happening before or after a save task started,
- onboarding `.onAppear` running before `.task`,
- preserving only one owner's local cache during refresh.

## Landed Design

The rewrite keeps a single UI-facing `FoodNotesStore`, but moves mutable
food-notes domain state behind a private `FoodNotesEngine` actor.

### Components

1. `FoodNotesStore` (`@MainActor`, `@Observable`)
- publishes view state,
- exposes explicit owner-scoped APIs,
- mirrors the active owner's preferences back into `Onboarding` only as a
  compatibility projection for existing progress logic.

2. `FoodNotesEngine` (`actor`)
- owns all mutable food-notes state,
- serializes refresh, mutation, sync, and reset operations,
- emits immutable snapshots back to `FoodNotesStore`.

3. `FoodNotesSnapshotBridge`
- hops actor snapshots onto the main actor,
- keeps the actor isolated from UI state mutation.

## Canonical State Model

```swift
typealias OwnerKey = String // "Everyone" or lowercase member UUID

struct FoodNotesOwnerState {
    var base: Preferences
    var working: Preferences
    var pendingReplacement: FoodNotesPendingReplacement?
    var version: Int
    var miscNotes: [String]
    var requiresSync: Bool
    var isSyncing: Bool
    var resetEpoch: UInt64
}
```

### Meaning

- `base`: last confirmed server snapshot for that owner.
- `working`: current local state shown in UI for that owner.
- `pendingReplacement`: most recent unsynced full-preferences write for that owner.
- `version`: optimistic concurrency version from backend.
- `miscNotes`: owner-scoped freeform notes carried with the same owner state.
- `requiresSync`: notes-only or migration-only sync flag.
- `isSyncing`: sync in flight for that owner.
- `resetEpoch`: invalidates stale async completions after owner reset.

## Key Architectural Rules

1. Every write is explicit about owner.
2. Owner switching is a read/projection change, not a write.
3. The engine actor is the only writer of owner state, versions, and sync flags.
4. UI never saves by "looking up current owner later" inside async work.
5. `onboardingStore.preferences` is not the source of truth.
6. Refresh rebuilds all owners, not just the currently selected one.
7. Stale sync completions are ignored after reset via `resetEpoch`.

## Public Store API

The UI writes through explicit methods:

```swift
func bootstrap(family: Family?, selectedMemberId: UUID?) async
func refreshFromServer(family: Family?) async
func setActiveMember(_ selectedMemberId: UUID?) async
func replacePreferences(_ preferences: Preferences, ownerKey: OwnerKey) async
func flushPendingSyncs(ownerKey: OwnerKey?) async
func clearOwnerState(for memberId: UUID) async
func resetLocalState() async
```

There is no implicit mutation API tied to a global active owner.

## UI Contract

Views now follow this contract:

1. Read active data from `foodNotesStore.currentPreferences`.
2. Capture `foodNotesStore.activeOwnerKey` at mutation time.
3. Call `replacePreferences(_:ownerKey:)` with that captured key.
4. Flush explicitly on important boundaries such as edit-sheet dismissal and view disappearance.

This removes the old `.onChange(of: store.preferences)` save pipeline.

## Refresh Algorithm

`bootstrap` and manual refresh both route through `refreshFromServer(family:)`.

Engine behavior:

1. Fetch all food notes from backend.
2. Parse server state into per-owner records.
3. Rebuild the in-memory owner map for the union of:
- existing local owners,
- server owners,
- `"Everyone"`,
- current active owner.
4. For each owner:
- update `base` from server,
- update `version` from server,
- keep `working = pendingReplacement.preferences` when a local unsynced write exists,
- otherwise set `working = base`.
5. Run single-member migration if needed.
6. Emit one coherent snapshot.

This means refresh cannot clobber local in-flight edits just because a different owner is active.

## Mutation Model

The landed implementation uses coalesced full-owner replacements, not an op log.

When UI changes preferences for an owner:

1. Normalize the new `Preferences`.
2. Store them as `pendingReplacement`.
3. Set `working` to that normalized value immediately.
4. Emit a snapshot immediately for optimistic UI.
5. Schedule a debounced owner-specific sync.

### Why this is still structurally safer

- the owner is explicit,
- the actor serializes all writes,
- there is at most one pending local replacement per owner,
- owner switches do not affect write routing,
- refresh preserves unsynced local `working` state per owner.

## Sync Algorithm

Sync is owner-scoped and tokenized.

1. Scheduling a sync records a token per owner.
2. Only the latest token for that owner is allowed to flush.
3. Sync sends the owner's current `working` preferences and `miscNotes` with the owner's current `version`.
4. On success:
- `base` becomes the server response,
- `version` is updated,
- matching `pendingReplacement` is cleared,
- `working` remains pending local data if a newer replacement arrived during sync, otherwise it becomes `base`.
5. On version mismatch:
- load the server's latest owner note from the error payload,
- update `base`, `version`, and `miscNotes`,
- keep `working = pendingReplacement.preferences` if a local replacement still exists,
- retry up to a bounded limit, then back off.
6. On transient failure:
- keep local pending state,
- clear `isSyncing`,
- retry later.

## Reset Safety

Owner reset and app reset increment `resetEpoch`.

Any async sync completion that returns after a reset is ignored if its captured
epoch no longer matches the current owner state. This prevents stale network
responses from resurrecting cleared data.

## Single-Member Migration

The old "Everyone" data migration is now engine-owned.

When a family has no `otherMembers`:

1. merge `"Everyone"` working data into the self-member owner,
2. merge misc notes the same way,
3. clear `"Everyone"`,
4. mark both owners for sync,
5. schedule sync from inside the engine.

The migration no longer depends on view lifecycle hooks.

## Derived Projection

The engine rebuilds two derived values from all owner `working` states:

1. `canvasPreferences`
- union view used for summary cards.

2. `itemMemberAssociations`
- map of section/item to owning members.

This rebuild happens from actor state, not from view-local caches.

## Invariants

These are the rules the implementation is designed around:

1. No mutation is accepted without an explicit owner key.
2. Active-owner changes do not mutate owner data.
3. `working` is always the UI-visible source for that owner.
4. `base` only changes from server refresh or successful sync responses.
5. `pendingReplacement` only clears after the matching write is acknowledged.
6. A stale scheduled sync token cannot flush newer state.
7. A stale network completion cannot reapply after reset.

## Tradeoffs

This rewrite intentionally chose correctness of ownership and async ordering over
fine-grained merge semantics.

### Current conflict policy

- within one client session: latest local owner snapshot wins,
- against concurrent remote edits for the same owner: the client retries with its
  latest local full-owner snapshot after version mismatch.

That is acceptable for the current product surface because it eliminates the
race conditions that were causing silent loss locally. If finer cross-device
merging is needed later, it should be added inside the actor, not in views.

## Verification Completed

1. Legacy owner-coupled write path removed from canvases and edit sheets.
2. Build verification completed with:

```bash
xcodebuild build -project IngrediCheck.xcodeproj -scheme IngrediCheck -destination 'id=8FA6A311-D245-4201-ABEA-50DF9C78140D' -derivedDataPath /tmp/IngrediCheckDerivedData
```

3. The rewrite compiles successfully (`BUILD SUCCEEDED`).

## Remaining Hardening Work

The architecture is landed, but automated regression coverage still needs to be
added in a dedicated test target:

- owner isolation tests,
- refresh-while-edit tests,
- version mismatch retry tests,
- reset-epoch stale completion tests,
- rapid member-switch stress tests.

Those should validate the actor behavior directly instead of relying on SwiftUI lifecycle tests.
