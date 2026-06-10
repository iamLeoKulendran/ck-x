#!/bin/bash
set -euo pipefail
fail() { echo "❌ $1"; exit 1; }
pass() { echo "✅ $1"; exit 0; }
FILE=/tmp/exam/q22/q22-static-web.yaml
[ -f "$FILE" ] || fail "Manifest missing: $FILE"
python3 -c "
import yaml, sys
d = yaml.safe_load(open('$FILE'))
assert d.get('kind') == 'Pod', 'kind must be Pod, got: ' + str(d.get('kind'))
assert d.get('metadata', {}).get('name') == 'q22-static-web', 'Pod name must be q22-static-web'
" || fail "Manifest YAML structure invalid (kind or name mismatch)"
pass "Static Pod manifest exists at /tmp/exam/q22/ with correct kind and name"
