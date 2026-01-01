#!/usr/bin/env python3
"""Extract bind entries from expanded Niri config."""
import sys


def extract_binds():
    """Extract bind blocks from stdin and print them to stdout."""
    inside_bind = False
    brace_depth = 0
    current_bind = []

    for line in sys.stdin:
        stripped = line.lstrip()

        # Skip empty or comment lines
        if stripped.startswith("//") or stripped.strip() == "":
            continue

        # Detect start of a bind block
        if not inside_bind and stripped.startswith("bind"):
            inside_bind = True
            brace_depth = stripped.count("{") - stripped.count("}")
            current_bind = [line]
            
            # Single-line bind
            if brace_depth == 0:
                print("".join(current_bind).rstrip())
                inside_bind = False
                current_bind = []
            continue

        # Process lines inside bind block
        if inside_bind:
            current_bind.append(line)
            brace_depth += stripped.count("{") - stripped.count("}")
            
            # End of bind block
            if brace_depth == 0:
                print("".join(current_bind).rstrip())
                inside_bind = False
                current_bind = []


def main():
    """Main entry point."""
    try:
        extract_binds()
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

