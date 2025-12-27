
import sys

# dictionary of key -> full bind text
binds = {}
order = []  # keep track of keys in the order we see new ones

for line in sys.stdin:
    # split key combo (before first '{')
    parts = line.split("{", 1)
    if len(parts) < 2:
        continue
    key_combo = parts[0].strip()

    # record or replace
    binds[key_combo] = line.rstrip()
    if key_combo in order:
        order.remove(key_combo)
    order.append(key_combo)

# print results
print("binds {")
for key in order:
    print("    " + binds[key])
print("}")

