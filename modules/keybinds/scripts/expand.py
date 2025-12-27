from pathlib import Path
import re

include_re = re.compile(r'include\s+"([^"]+)"')

def expand(file_path, seen=None):
    if seen is None:
        seen = set()

    file_path = Path(file_path).expanduser().resolve()
    if file_path in seen:
        return ""

    seen.add(file_path)
    output = []

    for line in file_path.read_text().splitlines():
        stripped = line.lstrip()

        # Ignore comment lines starting with //
        if stripped.startswith("//"):
            continue

        match = include_re.search(stripped)
        if match:
            inc = file_path.parent / match.group(1)
            output.append(expand(inc, seen))
        else:
            output.append(line)

    return "\n".join(output)

print(expand("~/.config/niri/config.kdl"))

