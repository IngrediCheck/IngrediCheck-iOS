#!/usr/bin/env python3
"""
Microcopy lint for IngrediCheck v2.0 (usePreviewFlow=true).

Checks:
- spaces before punctuation (e.g., "Hello !" → "Hello!")
- double punctuation / ASCII ellipses (".." / "..." / "!!" / "??")
- accidental newlines in UI strings
- a small set of known typos / banned variants (optional, high-signal only)

Usage:
  python3 scripts/microcopy_lint.py
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]

DEFAULT_SWIFT_ROOTS = [
    REPO_ROOT / "IngrediCheck",
]
DEFAULT_DYNAMIC_JSON = REPO_ROOT / "IngrediCheck" / "Store" / "dynamicJsonData.json"
DEFAULT_XCSTRINGS = REPO_ROOT / "IngrediCheck" / "Resources" / "Localizable.xcstrings"


# Heuristics copied/trimmed from the report generator.
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
    ToastManager\.shared\.show\s*\(
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
    \bproperties\s*:\s*\[
    """,
    re.VERBOSE,
)

ICON_ARG_RE = re.compile(r"(systemImage|systemName|icon|imageName|fileName|bgImageUrl|iconUrl)\s*:\s*$")


# Lint rules
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+[!?.,:;]")
ASCII_ELLIPSIS_RE = re.compile(r"\.\.\.")
DOUBLE_PERIOD_RE = re.compile(r"\.\.")
DOUBLE_BANG_RE = re.compile(r"!!+")
DOUBLE_QUESTION_RE = re.compile(r"\?\?+")
MIXED_PUNCT_RE = re.compile(r"!\?|\?!")
DOUBLE_SPACE_RE = re.compile(r" {2,}")

KNOWN_TYPO_RULES: list[tuple[re.Pattern[str], str]] = [
    (re.compile(r"\bIngrediPoiints\b", re.IGNORECASE), "Use “IngrediPoints”."),
    (re.compile(r"\bIngredientCheck\b", re.IGNORECASE), "Use “IngrediCheck”."),
    (re.compile(r"\bfoodnote(s)?\b", re.IGNORECASE), "Use “Food Notes”."),
    (re.compile(r"\bSign-in\b", re.IGNORECASE), "Use “Sign in”."),
]


@dataclass(frozen=True)
class SourceRef:
    path: Path
    line: int | None = None
    xc_key: str | None = None
    xc_lang: str | None = None
    json_path: str | None = None


@dataclass(frozen=True)
class LintIssue:
    code: str
    message: str
    value: str
    ref: SourceRef


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


def collect_swift_microcopy(swift_roots: list[Path]) -> list[tuple[str, SourceRef]]:
    swift_files: list[Path] = []
    for root in swift_roots:
        if root.exists():
            swift_files.extend(root.rglob("*.swift"))

    results: list[tuple[str, SourceRef]] = []

    for p in sorted({f.resolve() for f in swift_files}):
        text = p.read_text(encoding="utf-8", errors="replace")
        in_block = False
        for lineno, line in enumerate(skip_preview_blocks(text.splitlines()), start=1):
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

            if not UI_CONTEXT_RE.search(line):
                continue
            if SKIP_LINE_RE.search(line):
                continue

            for content, start_idx in extract_string_literals_with_positions(line):
                if is_icon_string(line, start_idx):
                    continue
                if should_skip_value(content):
                    continue
                results.append((content, SourceRef(path=p, line=lineno)))

    return results


def collect_dynamic_json_strings(path: Path) -> list[tuple[str, SourceRef]]:
    if not path.exists():
        return []

    data = json.loads(path.read_text(encoding="utf-8"))
    results: list[tuple[str, SourceRef]] = []

    ignored_keys = {
        "iconUrl",
        "bgImageUrl",
        "imageName",
        "systemImage",
        "systemName",
        "fileName",
        "color",
        "icon",
    }

    def join_path(segments: list[str]) -> str:
        out = ""
        for seg in segments:
            if seg.startswith("["):
                out += seg
            else:
                out += ("" if not out else ".") + seg
        return out

    def walk(obj: Any, segments: list[str]) -> None:
        if isinstance(obj, dict):
            for k, v in obj.items():
                walk(v, segments + [k])
            return
        if isinstance(obj, list):
            for i, v in enumerate(obj):
                walk(v, segments + [f"[{i}]"])
            return
        if isinstance(obj, str):
            last_key = next((s for s in reversed(segments) if not s.startswith("[")), "")
            if last_key in ignored_keys:
                return
            if should_skip_value(obj):
                return
            results.append((obj, SourceRef(path=path, json_path=join_path(segments))))

    walk(data, [])
    return results


def collect_xcstrings_strings(path: Path) -> list[tuple[str, SourceRef]]:
    if not path.exists():
        return []

    data = json.loads(path.read_text(encoding="utf-8"))
    strings = data.get("strings", {}) or {}

    results: list[tuple[str, SourceRef]] = []
    for key, payload in strings.items():
        localizations = (payload or {}).get("localizations", {}) or {}
        for lang, lang_payload in localizations.items():
            unit = (lang_payload or {}).get("stringUnit", {}) or {}
            value = unit.get("value")
            if not isinstance(value, str) or not value.strip():
                continue
            results.append((value, SourceRef(path=path, xc_key=key, xc_lang=lang)))

    return results


def lint_value(value: str, ref: SourceRef) -> list[LintIssue]:
    issues: list[LintIssue] = []

    if value != value.rstrip():
        issues.append(LintIssue("trailing-space", "Trailing whitespace.", value, ref))
    if value.startswith(" "):
        issues.append(LintIssue("leading-space", "Leading whitespace.", value, ref))
    if DOUBLE_SPACE_RE.search(value):
        issues.append(LintIssue("double-space", "Contains double spaces.", value, ref))

    if "\n" in value or "\\n" in value:
        issues.append(LintIssue("newline", "Contains a newline (avoid \\n for layout).", value, ref))

    if SPACE_BEFORE_PUNCT_RE.search(value):
        issues.append(LintIssue("space-before-punct", "Space before punctuation.", value, ref))

    if ASCII_ELLIPSIS_RE.search(value):
        issues.append(LintIssue("ellipsis", "Use “…” instead of “...”.", value, ref))
    elif DOUBLE_PERIOD_RE.search(value):
        issues.append(LintIssue("double-period", "Avoid double periods (“..”).", value, ref))

    if DOUBLE_BANG_RE.search(value) or DOUBLE_QUESTION_RE.search(value) or MIXED_PUNCT_RE.search(value):
        issues.append(LintIssue("double-punct", "Avoid double/mixed punctuation.", value, ref))

    for pat, help_text in KNOWN_TYPO_RULES:
        if pat.search(value):
            issues.append(LintIssue("typo", help_text, value, ref))

    return issues


def format_issue(issue: LintIssue) -> str:
    loc = str(issue.ref.path)
    if issue.ref.line is not None:
        loc += f":{issue.ref.line}"
    if issue.ref.xc_key is not None:
        loc += f":{issue.ref.xc_key}"
        if issue.ref.xc_lang:
            loc += f"({issue.ref.xc_lang})"
    if issue.ref.json_path is not None:
        loc += f":{issue.ref.json_path}"

    value_preview = issue.value.replace("\n", "\\n")
    return f"{loc}: [{issue.code}] {issue.message}  →  {value_preview!r}"


def main() -> int:
    swift_items = collect_swift_microcopy(DEFAULT_SWIFT_ROOTS)
    json_items = collect_dynamic_json_strings(DEFAULT_DYNAMIC_JSON)
    xc_items = collect_xcstrings_strings(DEFAULT_XCSTRINGS)

    all_items = swift_items + json_items + xc_items
    issues: list[LintIssue] = []
    for value, ref in all_items:
        issues.extend(lint_value(value, ref))

    if issues:
        for issue in issues:
            print(format_issue(issue))
        print(f"\nMicrocopy lint: {len(issues)} issue(s) found.")
        return 1

    print("Microcopy lint: OK (0 issues).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

