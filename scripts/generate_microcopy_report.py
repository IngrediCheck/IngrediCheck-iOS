#!/usr/bin/env python3
"""
Generate a v2.0 (usePreviewFlow=true) microcopy report.

This script traces SwiftUI view reachability from the preview-flow entrypoints
and extracts user-facing strings. It also includes dynamic onboarding copy from
`IngrediCheck/Store/dynamicJsonData.json`, and (if present) localized strings
from `IngrediCheck/Resources/Localizable.xcstrings`.

Usage:
  python3 scripts/generate_microcopy_report.py
  python3 scripts/generate_microcopy_report.py --output docs/PreviewFlowMicrocopyReport.md
"""

from __future__ import annotations

import argparse
import json
import re
from collections import OrderedDict, deque
from datetime import datetime
from pathlib import Path
from typing import Iterable


ENTRY_VIEW_TYPES = [
    "AppFlowRouter",
    "SplashScreen",
    "WelcomeView",
    "RootContainerView",
    "PersistentBottomSheet",
]


STRUCT_DECL_RE = re.compile(r"\bstruct\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^\n{]+)")
TYPE_CALL_RE = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\s*\(")

BLOCK_COMMENT_START = re.compile(r"/\*")
BLOCK_COMMENT_END = re.compile(r"\*/")

UI_CONTEXT_RE = re.compile(
    r"""
    \bText\s*\(|
    \bButton\s*\(|
    \bLabel\s*\(|
    \bTextField\s*\(|
    \bSecureField\s*\(|
    \.navigationTitle\s*\(|
    \.navigationBarTitle\s*\(|
    \.alert\s*\(|
    \.confirmationDialog\s*\(|
    \.searchable\s*\(|
    ToastManager\.shared\.show\s*\(|
    AttributedString\s*\(\s*markdown\s*:\s*|
    \bmarkdown\s*=\s*"|
    \b(title|titleOverride|subtitle|description|message|placeholder|prompt|header|footer|cta|buttonTitle|text)\s*:\s*"
    """,
    re.VERBOSE,
)

SKIP_LINE_RE = re.compile(
    r"""
    AnalyticsService\.|
    Notification\.Name\(|
    UserDefaults\.|
    Bundle\.main\.|
    \bLog\.|
    \bprint\(|
    URL\(string\s*:\s*"|
    supabase|
    keychain|
    GoTrue|
    sb_publishable_|
    \bproperties\s*:\s*\[|
    \btrackOnboarding\s*\(
    """,
    re.VERBOSE,
)

ICON_ARG_RE = re.compile(r"(systemImage|systemName|icon|imageName|fileName|bgImageUrl|iconUrl)\s*:\s*$")


def skip_preview_blocks(lines: Iterable[str]) -> Iterable[str]:
    """Yield lines outside SwiftUI #Preview blocks."""
    in_preview = False
    depth = 0
    started = False

    for line in lines:
        if in_preview:
            depth += line.count("{")
            depth -= line.count("}")
            if "{" in line:
                started = True
            if started and depth <= 0:
                in_preview = False
                depth = 0
                started = False
            continue

        if "#Preview" in line:
            in_preview = True
            depth = line.count("{") - line.count("}")
            started = "{" in line
            if depth == 0 and not started:
                # Best-effort: treat as entering a closure even if braces are later.
                depth = 1
            continue

        yield line


def _parse_string_literal_at(s: str, i: int) -> tuple[str, int]:
    """Parse a Swift string literal starting at s[i] == '\"'."""
    assert s[i] == '"'
    i += 1
    out: list[str] = []
    n = len(s)

    while i < n:
        ch = s[i]
        if ch == "\\":
            # interpolation
            if i + 1 < n and s[i + 1] == "(":
                out.append("{…}")
                i += 2
                depth = 1
                while i < n and depth > 0:
                    c = s[i]
                    if c == '"':
                        _, i = _parse_string_literal_at(s, i)
                        continue
                    if c == "(":
                        depth += 1
                    elif c == ")":
                        depth -= 1
                    i += 1
                continue

            # common escapes
            if i + 1 < n:
                esc = s[i + 1]
                if esc == "n":
                    out.append("\\n")
                    i += 2
                    continue
                if esc == "t":
                    out.append("\\t")
                    i += 2
                    continue
                if esc == "r":
                    out.append("\\r")
                    i += 2
                    continue
                if esc == '"':
                    out.append('"')
                    i += 2
                    continue
                if esc == "\\":
                    out.append("\\")
                    i += 2
                    continue

            out.append("\\")
            i += 1
            continue

        if ch == '"':
            return "".join(out), i + 1

        out.append(ch)
        i += 1

    return "".join(out), n


def extract_string_literals_with_positions(line: str) -> list[tuple[str, int]]:
    """Return [(content, start_index)] for normal Swift string literals on a line."""
    results: list[tuple[str, int]] = []
    i = 0
    n = len(line)

    while i < n:
        if line[i] == '"':
            if i > 0 and line[i - 1] == "\\":
                i += 1
                continue
            if i > 0 and line[i - 1] == "#":
                # raw strings (#"...") are ignored for now
                i += 1
                continue

            content, j = _parse_string_literal_at(line, i)
            results.append((content, i))
            i = j
            continue
        i += 1

    return results


def is_icon_string(line: str, start_idx: int) -> bool:
    """Heuristic: ignore literals used as icon/system image identifiers."""
    prefix = line[:start_idx]
    cut = max(prefix.rfind(","), prefix.rfind("("), prefix.rfind("{"))
    snippet = prefix[cut + 1 :].strip()
    return bool(ICON_ARG_RE.search(snippet))


def should_skip_value(s: str) -> bool:
    s = s.strip()
    if not s:
        return True
    if s in {"{…}", "#{…}"}:
        return True
    # Skip long internal identifiers/keys
    if re.fullmatch(r"[A-Za-z0-9_]+", s) and (" " not in s) and (len(s) > 18):
        return True
    # Skip hex-ish literals
    if re.fullmatch(r"#?[0-9A-Fa-f]{6,8}", s):
        return True
    return False


def md_inline_code(s: str) -> str:
    return "`" + s.replace("`", "\\`") + "`"


def iter_swift_files(*roots: Path, exclude_files: set[Path]) -> list[Path]:
    files: set[Path] = set()
    for root in roots:
        if root.exists():
            files |= {p.resolve() for p in root.rglob("*.swift")}
    return sorted(files - exclude_files)


def index_view_types(swift_files: list[Path]) -> dict[str, Path]:
    """Map SwiftUI view-like types (structs conforming to View/representable) to their file."""
    view_type_to_file: dict[str, Path] = {}

    for p in swift_files:
        text = p.read_text(encoding="utf-8", errors="replace")
        in_block = False
        for line in skip_preview_blocks(text.splitlines()):
            if in_block:
                if BLOCK_COMMENT_END.search(line):
                    in_block = False
                continue
            if BLOCK_COMMENT_START.search(line) and not BLOCK_COMMENT_END.search(line):
                in_block = True
                continue

            stripped = line.lstrip()
            if stripped.startswith("//"):
                continue

            m = STRUCT_DECL_RE.search(line)
            if not m:
                continue

            name, protos = m.group(1), m.group(2)
            if any(token in protos for token in ["View", "UIViewRepresentable", "UIViewControllerRepresentable"]):
                view_type_to_file.setdefault(name, p)

    return view_type_to_file


def reachable_view_files(view_type_to_file: dict[str, Path]) -> tuple[set[str], set[Path]]:
    reachable_types: set[str] = set()
    reachable_files: set[Path] = set()

    q = deque([t for t in ENTRY_VIEW_TYPES if t in view_type_to_file])

    while q:
        t = q.popleft()
        if t in reachable_types:
            continue
        reachable_types.add(t)

        f = view_type_to_file.get(t)
        if not f:
            continue
        reachable_files.add(f)

        text = f.read_text(encoding="utf-8", errors="replace")
        in_block = False
        for line in skip_preview_blocks(text.splitlines()):
            if in_block:
                if BLOCK_COMMENT_END.search(line):
                    in_block = False
                continue
            if BLOCK_COMMENT_START.search(line) and not BLOCK_COMMENT_END.search(line):
                in_block = True
                continue
            stripped = line.lstrip()
            if stripped.startswith("//"):
                continue

            for m in TYPE_CALL_RE.finditer(line):
                cand = m.group(1)
                if cand in view_type_to_file and cand not in reachable_types:
                    q.append(cand)

    return reachable_types, reachable_files


def extract_strings_from_swift_file(
    path: Path,
    *,
    include_all_literals: bool = False,
    include_helper_funcs: set[str] | None = None,
) -> OrderedDict[str, list[int]]:
    """Extract user-facing string literals from a Swift source file."""
    include_helper_funcs = include_helper_funcs or set()

    text = path.read_text(encoding="utf-8", errors="replace")

    in_block = False
    strings_to_lines: OrderedDict[str, list[int]] = OrderedDict()

    # Track helper function scopes (used for share-message builders)
    in_extra_func = False
    extra_depth = 0

    filtered_lines = list(skip_preview_blocks(text.splitlines()))

    for line_no, raw_line in enumerate(filtered_lines, 1):
        line = raw_line

        # Track extra func scopes even if line has no quotes
        if include_helper_funcs:
            if not in_extra_func:
                for fname in include_helper_funcs:
                    if re.search(rf"\bfunc\s+{re.escape(fname)}\b", line):
                        in_extra_func = True
                        extra_depth = line.count("{") - line.count("}")
                        if extra_depth <= 0:
                            extra_depth = 1
                        break
            else:
                extra_depth += line.count("{")
                extra_depth -= line.count("}")
                if extra_depth <= 0:
                    in_extra_func = False
                    extra_depth = 0

        if in_block:
            if BLOCK_COMMENT_END.search(line):
                in_block = False
            continue
        if BLOCK_COMMENT_START.search(line) and not BLOCK_COMMENT_END.search(line):
            in_block = True
            continue

        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue

        if '"' not in line:
            continue

        if not include_all_literals and not UI_CONTEXT_RE.search(line) and not in_extra_func:
            continue

        if SKIP_LINE_RE.search(line):
            continue

        # Skip pure asset identifiers unless combined with UI text
        if "Image(" in line and "Text(" not in line and "Label(" not in line and "Button(" not in line:
            continue

        for s, start_idx in extract_string_literals_with_positions(line):
            s_clean = s.strip()
            if should_skip_value(s_clean):
                continue
            if is_icon_string(line, start_idx):
                continue
            # Hide raw URLs unless the literal is intended user-facing content
            if s_clean.startswith("http") and "markdown" not in line and "Download from the App Store" not in s_clean:
                continue

            strings_to_lines.setdefault(s_clean, []).append(line_no)

    for k, v in list(strings_to_lines.items()):
        strings_to_lines[k] = sorted(set(v))

    return strings_to_lines


def load_dynamic_onboarding_steps(json_path: Path) -> list[dict]:
    if not json_path.exists():
        return []
    payload = json.loads(json_path.read_text(encoding="utf-8"))
    return payload.get("steps", [])


def load_xcstrings_strings(xcstrings_path: Path) -> dict[str, str]:
    """
    Parse a String Catalog and return base-language key->value mapping.

    NOTE: We only extract the `stringUnit.value` for the source language.
    """
    if not xcstrings_path.exists():
        return {}

    data = json.loads(xcstrings_path.read_text(encoding="utf-8"))
    source_language = data.get("sourceLanguage", "en")
    strings = data.get("strings", {})

    out: dict[str, str] = {}
    for key, entry in strings.items():
        localizations = entry.get("localizations", {})
        loc = localizations.get(source_language) or localizations.get("en") or {}
        string_unit = loc.get("stringUnit", {})
        value = string_unit.get("value")
        if isinstance(value, str) and value.strip():
            out[key] = value

    return out


def group_xcstrings_by_prefix(items: dict[str, str]) -> OrderedDict[str, list[tuple[str, str]]]:
    grouped: dict[str, list[tuple[str, str]]] = {}
    for key, value in items.items():
        prefix = key.split(".", 3)[:3]
        group = ".".join(prefix) if prefix else "other"
        grouped.setdefault(group, []).append((key, value))

    out: OrderedDict[str, list[tuple[str, str]]] = OrderedDict()
    for group in sorted(grouped.keys()):
        out[group] = sorted(grouped[group], key=lambda kv: kv[0])
    return out


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    ingredicheck_root = repo_root / "IngrediCheck"

    parser = argparse.ArgumentParser(description="Generate v2.0 preview-flow microcopy report.")
    parser.add_argument(
        "--output",
        default=str(repo_root / "docs" / "PreviewFlowMicrocopyReport.md"),
        help="Output markdown path (default: docs/PreviewFlowMicrocopyReport.md)",
    )
    args = parser.parse_args()

    output_path = Path(args.output).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    views_root = ingredicheck_root / "Views"
    components_root = ingredicheck_root / "Components"

    exclude_files = {
        (ingredicheck_root / "Config.swift").resolve(),
        (ingredicheck_root / "Config.swift.sample").resolve(),
    }

    swift_files = iter_swift_files(views_root, components_root, exclude_files=exclude_files)
    view_type_to_file = index_view_types(swift_files)
    reachable_types, reachable_files = reachable_view_files(view_type_to_file)

    # Extra non-view sources of user-facing copy
    extra_all_literals = {
        (ingredicheck_root / "Store" / "PreferenceExamples.swift").resolve(),
        (ingredicheck_root / "WebService.swift").resolve(),
        (ingredicheck_root / "Store" / "MemojiStore.swift").resolve(),
    }

    files_for_report = sorted({*reachable_files, *[p for p in extra_all_literals if p.exists()]})

    file_map: dict[str, OrderedDict[str, list[int]]] = OrderedDict()

    for p in files_for_report:
        rel = p.relative_to(ingredicheck_root).as_posix() if p.is_relative_to(ingredicheck_root) else p.as_posix()
        strings = extract_strings_from_swift_file(
            p,
            include_all_literals=p.resolve() in extra_all_literals,
            include_helper_funcs={"inviteShareMessage", "formattedInviteCode"} if p.name == "PersistentBottomSheet.swift" else set(),
        )
        if strings:
            file_map[rel] = strings

    dynamic_steps = load_dynamic_onboarding_steps(ingredicheck_root / "Store" / "dynamicJsonData.json")

    # Localized strings from String Catalog (if present)
    xcstrings_path = ingredicheck_root / "Resources" / "Localizable.xcstrings"
    xcstrings_items = load_xcstrings_strings(xcstrings_path)
    xcstrings_grouped = group_xcstrings_by_prefix(xcstrings_items) if xcstrings_items else OrderedDict()

    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    out_lines: list[str] = []

    out_lines.append("# Preview Flow (usePreviewFlow=true) — Microcopy Report")
    out_lines.append("")
    out_lines.append(f"_Generated: {now}_")
    out_lines.append("")
    out_lines.append("## Scope")
    out_lines.append("")
    out_lines.append(
        "- Entry point when `usePreviewFlow == true`: `Views/AppFlowRouter.swift` → `SplashScreen` → `WelcomeView` / `RootContainerView`"
    )
    out_lines.append(
        "- This report is generated by tracing reachable SwiftUI view types starting from the preview-flow root views, then extracting hardcoded user-facing strings."
    )
    if xcstrings_items:
        out_lines.append("- Includes localized strings from `IngrediCheck/Resources/Localizable.xcstrings` (source language).")
    out_lines.append("- Includes dynamic onboarding copy from `Store/dynamicJsonData.json`.")
    out_lines.append(
        "- Excludes SwiftUI `#Preview` blocks, backend-provided content (e.g., product names / scan results), and analytics/internal identifiers."
    )
    out_lines.append("")

    if xcstrings_items:
        out_lines.append("## Localized strings (`IngrediCheck/Resources/Localizable.xcstrings`)")
        out_lines.append("")
        for group, pairs in xcstrings_grouped.items():
            out_lines.append(f"### `{group}.*`")
            out_lines.append("")
            for key, value in pairs:
                out_lines.append(f"- **{md_inline_code(key)}**: {md_inline_code(value)}")
            out_lines.append("")

    out_lines.append("## SwiftUI / App strings (reachable views only)")
    out_lines.append("")

    for rel, mapping in file_map.items():
        out_lines.append(f"### `{rel}`")
        out_lines.append("")
        for text, line_nos in mapping.items():
            lines_str = ", ".join(str(n) for n in line_nos)
            out_lines.append(f"- **Lines {lines_str}**: {md_inline_code(text)}")
        out_lines.append("")

    out_lines.append("## Dynamic onboarding copy (`Store/dynamicJsonData.json`)")
    out_lines.append("")

    if not dynamic_steps:
        out_lines.append("_No steps found (file missing or empty)._")
    else:
        for step in dynamic_steps:
            step_id = step.get("id", "")
            step_type = step.get("type", "")
            header = step.get("header", {})
            name = header.get("name", "")
            out_lines.append(f"### Step: {md_inline_code(name)} (id: `{step_id}`, type: `{step_type}`)")
            out_lines.append("")

            def emit_variant(label: str, variant: dict | None) -> None:
                if not variant:
                    return
                q = variant.get("question")
                d = variant.get("description")
                if q is not None:
                    out_lines.append(f"- **{label} question**: {md_inline_code(str(q))}")
                if d is not None:
                    out_lines.append(f"- **{label} description**: {md_inline_code(str(d))}")

            emit_variant("Individual", header.get("individual"))
            emit_variant("Family", header.get("family"))
            emit_variant("Single-member", header.get("singleMember"))

            content = step.get("content", {})

            options = content.get("options")
            if isinstance(options, list):
                out_lines.append("- **Options**:")
                for opt in options:
                    opt_name = opt.get("name", "")
                    opt_icon = opt.get("icon")
                    if opt_icon:
                        out_lines.append(f"  - {md_inline_code(str(opt_name))} ({md_inline_code(str(opt_icon))})")
                    else:
                        out_lines.append(f"  - {md_inline_code(str(opt_name))}")

            sub_steps = content.get("subSteps")
            if isinstance(sub_steps, list):
                out_lines.append("- **Sub-steps**:")
                for ss in sub_steps:
                    ss_title = ss.get("title", "")
                    ss_desc = ss.get("description", "")
                    out_lines.append(f"  - **{md_inline_code(str(ss_title))}**: {md_inline_code(str(ss_desc))}")
                    ss_opts = ss.get("options")
                    if isinstance(ss_opts, list) and ss_opts:
                        out_lines.append("    - Options:")
                        for opt in ss_opts:
                            opt_name = opt.get("name", "")
                            opt_icon = opt.get("icon")
                            if opt_icon:
                                out_lines.append(f"      - {md_inline_code(str(opt_name))} ({md_inline_code(str(opt_icon))})")
                            else:
                                out_lines.append(f"      - {md_inline_code(str(opt_name))}")

            regions = content.get("regions")
            if isinstance(regions, list):
                out_lines.append("- **Regions**:")
                for r in regions:
                    r_name = r.get("name", "")
                    out_lines.append(f"  - **{md_inline_code(str(r_name))}**")
                    sub = r.get("subRegions")
                    if isinstance(sub, list) and sub:
                        for opt in sub:
                            opt_name = opt.get("name", "")
                            opt_icon = opt.get("icon")
                            if opt_icon:
                                out_lines.append(f"    - {md_inline_code(str(opt_name))} ({md_inline_code(str(opt_icon))})")
                            else:
                                out_lines.append(f"    - {md_inline_code(str(opt_name))}")

            out_lines.append("")

    output_path.write_text("\n".join(out_lines).rstrip() + "\n", encoding="utf-8")

    print(f"Wrote report to: {output_path}")
    print(f"Indexed view types: {len(view_type_to_file)}")
    print(f"Reachable view types: {len(reachable_types)}")
    print(f"Reachable Swift files: {len(reachable_files)}")
    print(f"Files with extracted strings: {len(file_map)}")
    print(f"Dynamic steps: {len(dynamic_steps)}")
    if xcstrings_items:
        print(f"String catalog entries: {len(xcstrings_items)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

