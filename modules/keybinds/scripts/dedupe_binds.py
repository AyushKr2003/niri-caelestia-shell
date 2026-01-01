#!/usr/bin/env python3
"""Deduplicate bind entries, keeping the last occurrence of each key combo."""
import sys


def deduplicate_binds():
    """Read bind entries from stdin, deduplicate by key, and print results."""
    # Dictionary of key -> full bind text
    binds = {}
    order = []  # Track keys in the order we see new ones

    for line in sys.stdin:
        # Split key combo (before first '{')
        parts = line.split("{", 1)
        if len(parts) < 2:
            continue
        
        key_combo = parts[0].strip()

        # Record or replace (last occurrence wins)
        binds[key_combo] = line.rstrip()
        if key_combo in order:
            order.remove(key_combo)
        order.append(key_combo)

    # Print wrapped in binds block
    print("binds {")
    for key in order:
        print("    " + binds[key])
    print("}")


def main():
    """Main entry point."""
    try:
        deduplicate_binds()
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

