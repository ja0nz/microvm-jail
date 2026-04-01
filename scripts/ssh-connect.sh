#!/usr/bin/env bash
set -euo pipefail

BRIDGE="${1:-microbr}"

# Write private key to a temp file and clean up on exit
keyfile=$(mktemp)
trap 'rm -f "$keyfile"' EXIT
chmod 600 "$keyfile"
cat > "$keyfile" <<'EOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAEk9/hEhMVtIufPiLUKXXRPvu5kKMgiuCYlpqWJxtIswAAAJDSY6cV0mOn
FQAAAAtzc2gtZWQyNTUxOQAAACAEk9/hEhMVtIufPiLUKXXRPvu5kKMgiuCYlpqWJxtIsw
AAAEBWUwHXyBr53W6e724iiNT8ZacvbbtTGF2EoP7W/PTiXAST3+ESExW0i58+ItQpddE+
+7mQoyCK4JiWmpYnG0izAAAAB21lQG5hbm8BAgMEBQY=
-----END OPENSSH PRIVATE KEY-----
EOF

mapfile -t leases < <(
  networkctl status "$BRIDGE" 2>/dev/null \
    | grep -oP '\d+\.\d+\.\d+\.\d+(?= \(to)'
)

if [[ ${#leases[@]} -eq 0 ]]; then
  echo "No DHCP leases found on $BRIDGE" >&2
  exit 1
fi

if [[ ${#leases[@]} -eq 1 ]]; then
  ip="${leases[0]}"
else
  echo "Multiple leases on $BRIDGE:"
  select ip in "${leases[@]}"; do
    [[ -n "$ip" ]] && break
  done
fi

echo "Connecting to $ip..."
exec ssh \
  -i "$keyfile" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  root@"$ip"
