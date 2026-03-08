# IngrediCheck iOS Maestro Tests

Maestro smoke tests for the simulator barcode scan QA path.

## Why this setup

This suite follows the parts of Maestro's recommended structure that matter:
- a workspace-level `.maestro/config.yaml`
- isolated flows that do not depend on execution order
- shared setup in `subflows/`
- explicit launch arguments instead of ad hoc app state
- stable accessibility identifiers for elements the tests need to touch

Unlike the older `kincalendar` suite, these flows are intentionally self-contained. They do not rely on one prior flow creating state for the next one.

## What it covers

- `01_scan_success.yaml`: launches the app in debug scan QA mode and verifies a successful barcode scan renders a result card
- `02_open_product_detail.yaml`: launches the app in debug scan QA mode, scans a known-good barcode, and verifies product detail navigation

## What it does not cover

- optical camera detection on a real device
- photo-mode scanning
- fully mocked backend behavior

These flows test the app/backend barcode pipeline in simulator using the debug barcode injector.

## Prerequisites

1. Maestro CLI installed

```bash
brew tap mobile-dev-inc/tap
brew install maestro
```

2. Xcode with an iOS simulator available
3. The app branch containing `DebugScanQAMode` and the debug barcode injector

## Running the suite

```bash
./.maestro/scripts/run-tests.sh
```

Optional environment variables:

```bash
SIM_NAME="iPhone 16 Pro" ./.maestro/scripts/run-tests.sh
MAESTRO_INCLUDE_TAGS="smoke" ./.maestro/scripts/run-tests.sh
```

## Running a single flow manually

Build and install the app first, then:

```bash
cd .maestro
maestro test --config config.yaml flows/01_scan_success.yaml
```

## Test structure

- `flows/`: top-level runnable test cases
- `subflows/`: shared launch and barcode injection steps
- `scripts/run-tests.sh`: boots a simulator, builds the app, installs it, and runs the suite

## Notes

- The suite uses the `debugScanQA` launch flag, which the app maps to the existing simulator-only debug scan mode.
- `clearState` and `clearKeychain` are used on launch so each flow starts from a clean app session.
- The flows use broad regex matches for known-good products instead of hard-coding every character of the backend response.
- The invalid-barcode path is still better covered manually right now because fresh sessions with no food notes do not surface a stable error-specific UI state.
