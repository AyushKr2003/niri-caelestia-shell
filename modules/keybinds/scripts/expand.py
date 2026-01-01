#!/usr/bin/env python3
"""Expand include directives in Niri config files."""
import sys
from pathlib import Path
import re

INCLUDE_RE = re.compile(r'include\s+"([^"]+)"')


def expand(file_path: str, seen: set = None) -> str:
    """Recursively expand a config file, processing include directives.
    
    Args:
        file_path: Path to the config file to expand
        seen: Set of already visited paths to prevent circular includes
    
    Returns:
        Expanded config content as a string
    """
    if seen is None:
        seen = set()

    try:
        file_path = Path(file_path).expanduser().resolve()
    except Exception as e:
        print(f"Error resolving path '{file_path}': {e}", file=sys.stderr)
        return ""

    if file_path in seen:
        print(f"Warning: Circular include detected: {file_path}", file=sys.stderr)
        return ""

    if not file_path.exists():
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        return ""

    seen.add(file_path)
    output = []

    try:
        for line in file_path.read_text().splitlines():
            stripped = line.lstrip()

            # Ignore comment lines starting with //
            if stripped.startswith("//"):
                continue

            match = INCLUDE_RE.search(stripped)
            if match:
                inc = file_path.parent / match.group(1)
                output.append(expand(str(inc), seen))
            else:
                output.append(line)
    except Exception as e:
        print(f"Error reading {file_path}: {e}", file=sys.stderr)
        return ""

    return "\n".join(output)


def main():
    """Main entry point."""
    config_path = "~/.config/niri/config.kdl"
    result = expand(config_path)
    if result:
        print(result)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()

