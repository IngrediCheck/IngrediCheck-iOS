# Avatar Selection Implementation Comparison

## Overview
Three views share similar UI for avatar selection but have different implementation approaches:
- **AddMoreMembers.swift** - Adding new family members
- **WhatsYourName.swift** - Creating self member during onboarding
- **EditMember.swift** - Editing existing members

## Key Differences

### 1. **Avatar Selection Logic & Data Flow**

#### AddMoreMembers.swift
- **Approach**: Uses callback pattern with `continuePressed: (String, UIImage?, String?, String?) async throws -> Void`
- **Flow**: Collects all data (name, uploadImage, storagePath, colorHex) → Passes to callback → Callback handles `addMemberImmediate`
- **Custom Memoji Check**: Checks `memojiStore.image` (UIImage) for custom generated memojis
- **Code Pattern**:
```swift
var uploadImage: UIImage? = nil
var storagePath: String? = nil
var colorHex: String? = nil

// Collect data...
try await continuePressed(trimmed, uploadImage, storagePath, colorHex)
```

#### WhatsYourName.swift
- **Approach**: Directly calls FamilyStore methods
- **Flow**: Directly calls `setPendingSelfMemberAvatarFromMemoji` or `setPendingSelfMemberAvatar`
- **Custom Memoji Check**: Checks `memojiStore.imageStoragePath` (String) for custom generated memojis
- **Code Pattern**:
```swift
if selectedImageName.hasPrefix("memoji_") {
    await familyStore.setPendingSelfMemberAvatarFromMemoji(
        storagePath: selectedImageName,
        backgroundColorHex: colorHex
    )
} else if let storagePath = memojiStore.imageStoragePath, !storagePath.isEmpty {
    await familyStore.setPendingSelfMemberAvatarFromMemoji(...)
}
```

#### EditMember.swift
- **Approach**: Directly calls FamilyStore methods (handles both self and other members)
- **Flow**: Directly calls `setPendingSelfMemberAvatarFromMemoji` or `setAvatarForPendingOtherMemberFromMemoji`
- **Custom Memoji Check**: Checks `memojiStore.imageStoragePath` (String) for custom generated memojis
- **Code Pattern**:
```swift
if isSelf {
    // Handle self member
    await familyStore.setPendingSelfMemberAvatarFromMemoji(...)
} else {
    // Handle other member
    await familyStore.setAvatarForPendingOtherMemberFromMemoji(...)
}
```

### 2. **Custom Memoji Detection**

| View | Custom Memoji Check |
|------|---------------------|
| **AddMoreMembers** | `memojiStore.image` (UIImage) |
| **WhatsYourName** | `memojiStore.imageStoragePath` (String) |
| **EditMember** | `memojiStore.imageStoragePath` (String) |

**Issue**: AddMoreMembers checks for `UIImage` while others check for `String` path. This inconsistency could cause issues.

### 3. **Name Validation**

| View | Validation |
|------|------------|
| **AddMoreMembers** | ✅ Full validation: letters only, 25 char limit, 3 words max |
| **WhatsYourName** | ✅ Full validation: letters only, 25 char limit, 3 words max |
| **EditMember** | ❌ Basic validation: only checks if empty |

**Issue**: EditMember doesn't filter input or enforce limits.

### 4. **Plus Button Navigation**

| View | previousRouteForGenerateAvatar |
|------|-------------------------------|
| **AddMoreMembers** | Sets to `.addMoreMembers` |
| **WhatsYourName** | ❌ Doesn't set (defaults to onboarding) |
| **EditMember** | Sets to `.editMember(memberId, isSelf)` or `.addMoreMembersMinimal` |

**Issue**: WhatsYourName doesn't set the route, which might cause navigation issues.

### 5. **State Management**

| View | State Reset/Cleanup |
|------|-------------------|
| **AddMoreMembers** | ✅ Has `resetMemojiSelectionState()` called in `onAppear` |
| **WhatsYourName** | ❌ No state reset |
| **EditMember** | ✅ Seeds initial values from store in `onAppear` |

### 6. **Error Handling**

| View | Error Handling |
|------|---------------|
| **AddMoreMembers** | ✅ Try-catch around `continuePressed` callback |
| **WhatsYourName** | ✅ Try-catch around `continuePressed` callback |
| **EditMember** | ❌ No error handling (synchronous `handleSave`) |

### 7. **Button Text & Actions**

| View | Button Text | Action |
|------|------------|--------|
| **AddMoreMembers** | "Add Member" | Calls `handleAddMember` |
| **WhatsYourName** | "Continue" | Calls `handleContinue` |
| **EditMember** | "Save" | Calls `handleSave` (synchronous) |

## Recommendations for Consistency

### 1. **Unify Custom Memoji Detection**
All views should check `memojiStore.imageStoragePath` (String) instead of `memojiStore.image` (UIImage):
- Update AddMoreMembers to check `imageStoragePath` like the others

### 2. **Add Name Validation to EditMember**
EditMember should have the same validation as AddMoreMembers and WhatsYourName:
- Filter to letters and spaces only
- Limit to 25 characters
- Limit to 3 words max

### 3. **Set Navigation Route in WhatsYourName**
WhatsYourName should set `memojiStore.previousRouteForGenerateAvatar` when navigating to GenerateAvatar:
```swift
memojiStore.previousRouteForGenerateAvatar = .whatsYourName
```

### 4. **Add Error Handling to EditMember**
EditMember's `handleSave` should handle errors properly, especially for async operations.

### 5. **Consider Extracting Common Logic**
The avatar selection UI and logic could be extracted into a reusable component to reduce duplication.

## Current Implementation Status

✅ **Consistent**:
- Avatar list (memoji_1 through memoji_14)
- UI layout (fixed plus button + divider + scrollable memojis)
- Local memoji detection (`hasPrefix("memoji_")`)
- Color extraction using `toHex()`

❌ **Inconsistent**:
- Custom memoji detection (UIImage vs String)
- Name validation (full vs basic)
- Navigation route setting
- Error handling
- State management
