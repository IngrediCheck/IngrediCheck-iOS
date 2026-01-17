#!/usr/bin/env python3
"""Migrate print() statements to Log.debug/error/warning calls."""

import re
import os
from pathlib import Path

def migrate_file(filepath: Path) -> int:
    """Migrate a single file, return count of replacements."""
    content = filepath.read_text()
    original = content
    count = 0

    # Add import os after the last import if not present
    if 'import os' not in content:
        # Find the last import line
        import_pattern = re.compile(r'^import \w+.*$', re.MULTILINE)
        imports = list(import_pattern.finditer(content))
        if imports:
            last_import = imports[-1]
            insert_pos = last_import.end()
            content = content[:insert_pos] + '\nimport os' + content[insert_pos:]

    # Pattern to match print("[CATEGORY] message")
    pattern = re.compile(r'print\("\[([^\]]+)\] ([^"]*(?:\([^)]*\)[^"]*)*)"')

    def replace_print(match):
        nonlocal count
        count += 1
        category = match.group(1)
        message = match.group(2)

        # Determine log level based on content
        if '❌' in message or 'error:' in message.lower() or 'failed' in message.lower():
            return f'Log.error("{category}", "{message}")'
        elif '⚠️' in message:
            return f'Log.warning("{category}", "{message}")'
        else:
            return f'Log.debug("{category}", "{message}")'

    content = pattern.sub(replace_print, content)

    # Handle multi-line strings with interpolation
    # Pattern for print statements that might span multiple expressions
    pattern2 = re.compile(r'print\("\[([^\]]+)\] (.+?)"\)', re.DOTALL)

    def replace_print2(match):
        nonlocal count
        count += 1
        category = match.group(1)
        message = match.group(2)

        if '❌' in message or 'error:' in message.lower() or 'failed' in message.lower():
            return f'Log.error("{category}", "{message}")'
        elif '⚠️' in message:
            return f'Log.warning("{category}", "{message}")'
        else:
            return f'Log.debug("{category}", "{message}")'

    # Only apply if still has print statements
    if 'print("[' in content:
        content = pattern2.sub(replace_print2, content)

    if content != original:
        filepath.write_text(content)
        return count
    return 0

def main():
    base = Path('/Users/sanket/.ccw/worktrees/IngrediCheck-iOS--food-notes-summary/IngrediCheck')

    # Find all Swift files with print statements
    files_to_migrate = []
    for filepath in base.rglob('*.swift'):
        if 'print("[' in filepath.read_text():
            files_to_migrate.append(filepath)

    print(f"Found {len(files_to_migrate)} files to migrate")

    total = 0
    for filepath in sorted(files_to_migrate):
        count = migrate_file(filepath)
        if count > 0:
            print(f"  {filepath.relative_to(base)}: {count} replacements")
            total += count

    print(f"\nTotal: {total} print statements migrated")

if __name__ == '__main__':
    main()
