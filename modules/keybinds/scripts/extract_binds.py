import sys
import re

inside_bind = False
brace_depth = 0
current_bind = []

for line in sys.stdin:
    stripped = line.lstrip()

    # skip empty/comment lines
    if stripped.startswith("//") or stripped.strip() == "":
        continue

    # detect start of a bind
    if not inside_bind and stripped.startswith("bind"):
        inside_bind = True
        brace_depth = stripped.count("{") - stripped.count("}")
        current_bind = [line]
        if brace_depth == 0:
            print("".join(current_bind).rstrip())
            inside_bind = False
            current_bind = []
        continue

    if inside_bind:
        current_bind.append(line)
        brace_depth += stripped.count("{")
        brace_depth -= stripped.count("}")
        if brace_depth == 0:
            print("".join(current_bind).rstrip())
            inside_bind = False
            current_bind = []

