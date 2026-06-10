#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q22/q22-static-web.yaml
[ -f "$FILE" ] || fail "Manifest missing: $FILE"
python3 -c "
import yaml
d = yaml.safe_load(open('$FILE'))
containers = d.get('spec', {}).get('containers', [])
assert containers, 'No containers defined in spec'
c = containers[0]
assert c.get('image') == 'nginx:1.25', 'Image must be nginx:1.25, got: ' + str(c.get('image'))
ports = c.get('ports', [])
assert any(p.get('containerPort') == 80 for p in ports), 'containerPort 80 must be defined'
" || fail "Container spec validation failed (image or containerPort mismatch)"
pass "Static Pod manifest has correct image nginx:1.25 and containerPort 80"
