# Microcopy Style Guide (v2.0 / Preview Flow)

This guide defines the voice, terminology rules, and formatting standards for all user-facing copy in IngrediCheck v2.0 (enabled by `usePreviewFlow == true`).

If a string appears in the v2.0 microcopy report (`docs/PreviewFlowMicrocopyReport.md`), it should follow this guide.

## Voice & tone

- **Friendly + playful, never confusing**: warm and human, but prioritize clarity over flair.
- **Earned excitement**: avoid accidental hype (e.g., double exclamation points). If we use excitement, do it intentionally and sparingly.
- **Direct and reassuring**: tell the user what’s happening and what to do next.
- **No blame**: errors should not imply user fault.

## Casing conventions

- **Titles/headings**: sentence case by default (e.g., “Ready to scan your first product?”).\n  - Exception: existing design patterns that use all-caps section labels (e.g., Settings sections) may stay all-caps.
- **Buttons/CTAs**: sentence case (e.g., “Continue”, “Not now”, “Open Settings”).\n  - Prefer verbs. Avoid “Yes/No” unless the question truly requires binary choice.

## Punctuation & typography

- **No spaces before punctuation**: use `! ? . ,` without a preceding space.
- **No double punctuation**: avoid `..`, `!!`, `?!` unless explicitly designed for a branded moment.
- **Ellipses**: use the ellipsis character `…` for trailing ellipses.\n  - Use for “in progress / loading” only (e.g., “Submitting your photo…”).
- **Quotes**: prefer typographic quotes in user-facing copy (`“ ”`) when the text is meant to be displayed (not keys).\n  - Avoid quoting entire placeholder strings unless it’s part of the UI concept.

## Newlines (`\\n`) and layout safety

- **Do not use `\\n` to force visual line breaks** in localized UI strings.\n  - Instead, let SwiftUI wrap naturally or structure layout as multiple `Text` blocks.
- **Allowed uses of `\\n`**:\n  - share messages / exported text (e.g., invite messages)\n  - content where line breaks are semantically meaningful (rare)

When we remove a layout-driven newline, we **must compensate in layout** (padding, `multilineTextAlignment`, `fixedSize`, spacing) and verify on small + large devices.

## CTA standards (preferred set)

Use consistent CTAs across screens. Prefer these labels:

- **Primary**: “Continue”, “Get started”, “Scan a product”, “Invite”, “Save”, “Try again”
- **Secondary**: “Not now”, “Maybe later”, “Back”, “Cancel”
- **System**: “Open Settings”, “OK”

Guidelines:

- Avoid “Start Over” unless there is a clear destructive reset.\n  Prefer “Clear code” / “Try again” for invite codes.
- Avoid “Go to Home” in most contexts. Prefer “Continue” or “Go to Home” only when navigation context is explicit.

## Errors, empty states, and system prompts

### Error template (recommended)

- **Title**: what failed (short)\n  Example: “Couldn’t verify invite code”
- **Message**: what happened + what to do next\n  Example: “Check the code and try again. If it still doesn’t work, ask your family to resend an invite.”
- **Action**: a single next step\n  Example: “Try again”

Avoid raw technical prefixes (`❌ Error:`) in user-facing UI. If we need raw details, keep them behind a debug-only affordance or logs.

### Empty states

- Name the empty state.\n  Example: “No scans yet”
- Give one friendly next step.\n  Example: “Scan your first product to see results here.”

## Localization / maintainability rules

- Prefer **centralized strings** in `Localizable.xcstrings` for v2.0.\n  Inline literals in Swift should be reserved for:\n  - non-user-facing identifiers\n  - truly ephemeral debug-only content\n  - or strings not yet migrated (temporary)
- Prefer placeholder formatting over concatenation.\n  Avoid splitting user-facing sentences across multiple `Text()` calls unless it’s a layout choice that preserves localization correctness.

