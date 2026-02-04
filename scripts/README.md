# Scripts

## Microcopy report (v2.0 preview flow)

Generates an inventory of user-facing strings shown when `usePreviewFlow == true`, plus dynamic onboarding copy from `dynamicJsonData.json`.

Output: `docs/PreviewFlowMicrocopyReport.md`

Run:

```bash
python3 scripts/generate_microcopy_report.py
```

## Microcopy lint (v2.0 preview flow)

Lightweight checks to prevent common microcopy regressions (typos, spacing before punctuation, double punctuation, and accidental `\n` in UI strings).

Run:

```bash
python3 scripts/microcopy_lint.py
```

