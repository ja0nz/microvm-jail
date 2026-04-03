#!/usr/bin/env bash
# Check: resolvectl query <vm-name>.mvm
set -euo pipefail
NAME="${1:?Usage: ssh-connect <vm-name>}"
DOMAIN="mvm"

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

echo "Connecting to ${NAME}.${DOMAIN}..."
exec ssh \
  -i "$keyfile" \
  -o IdentitiesOnly=yes \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o LogLevel=ERROR \
  root@"${NAME}.${DOMAIN}"
