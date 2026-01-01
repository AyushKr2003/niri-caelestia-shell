#!/usr/bin/env python3
"""Convert bind entries to pretty JSON format."""
import sys
import re
import json

# Regular expressions for parsing
HOTKEY_TITLE_RE = re.compile(r'hotkey-overlay-title\s*=\s*"([^"]+)"')
BRACE_ACTION_RE = re.compile(r'\{\s*([^;]+);')
ATTR_RE = re.compile(
    r'\s+(hotkey-overlay-title="[^"]+"|'
    r'repeat=false|'
    r'allow-when-locked=true|'
    r'allow-inhibiting=false|'
    r'cooldown-ms=\d+)'
)


def clean_key(key: str) -> str:
    """Remove attributes from key string and normalize whitespace.
    
    Args:
        key: Raw key string with potential attributes
    
    Returns:
        Cleaned key string
    """
    return " ".join(ATTR_RE.sub("", key).split())


def prettify_action(action: str) -> str:
    """Convert action string to human-readable format.
    
    Args:
        action: Raw action string
    
    Returns:
        Prettified action string
    """
    return action.replace("-", " ").replace("_", " ").strip().capitalize()


def parse_binds():
    """Parse bind entries from stdin and return as list of dicts."""
    results = []

    for line in sys.stdin:
        stripped = line.strip()
        
        # Skip empty lines and wrapper lines
        if not stripped or stripped in ("binds {", "}"):
            continue
        
        # Must have opening brace
        if "{" not in stripped:
            continue

        # Extract key part
        key_part, _ = stripped.split("{", 1)
        key = clean_key(key_part.strip())

        # Try to extract action from hotkey-overlay-title first
        title_match = HOTKEY_TITLE_RE.search(stripped)
        if title_match:
            action = title_match.group(1)
        else:
            # Fall back to action in braces
            action_match = BRACE_ACTION_RE.search(stripped)
            action = prettify_action(action_match.group(1)) if action_match else "Unknown"

        results.append({
            "key": key,
            "action": action
        })

    return results


def main():
    """Main entry point."""
    try:
        binds = parse_binds()
        print(json.dumps(binds, indent=2))
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
