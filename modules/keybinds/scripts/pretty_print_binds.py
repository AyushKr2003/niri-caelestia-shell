import sys
import re
import json

hotkey_title_re = re.compile(r'hotkey-overlay-title\s*=\s*"([^"]+)"')
brace_action_re = re.compile(r'\{\s*([^;]+);')

ATTR_RE = re.compile(
    r'\s+(hotkey-overlay-title="[^"]+"|'
    r'repeat=false|'
    r'allow-when-locked=true|'
    r'allow-inhibiting=false|'
    r'cooldown-ms=\d+)'
)

def clean_key(key):
    return " ".join(ATTR_RE.sub("", key).split())

def prettify_action(action):
    return action.replace("-", " ").replace("_", " ").strip().capitalize()

results = []

for line in sys.stdin:
    stripped = line.strip()
    if not stripped or stripped in ("binds {", "}"):
        continue
    if "{" not in stripped:
        continue

    key_part, _ = stripped.split("{", 1)
    key = clean_key(key_part.strip())

    title = hotkey_title_re.search(stripped)
    if title:
        action = title.group(1)
    else:
        act = brace_action_re.search(stripped)
        action = prettify_action(act.group(1)) if act else "Unknown"

    results.append({
        "key": key,
        "action": action
    })

print(json.dumps(results, indent=2))
