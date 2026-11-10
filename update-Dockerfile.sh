#!/bin/bash
# Update version ARGs in Dockerfile in-place using ./hack/show-latest-releases.sh
#
# Requirements: bash, curl, jq, git, python3 with "packaging" module, sed
# (on Ubuntu: apt-get install -y curl jq git python3-packaging)
set -eu -o pipefail

cd "$(dirname "$0")"

DOCKERFILE="${DOCKERFILE:-Dockerfile}"

for cmd in curl jq git python3 sed; do
	command -v "$cmd" >/dev/null || {
		echo >&2 "ERROR: required command not found: $cmd"
		exit 1
	}
done
python3 -c 'import packaging' 2>/dev/null || {
	echo >&2 "ERROR: python3 module 'packaging' not found (apt-get install -y python3-packaging)"
	exit 1
}
[ -f "$DOCKERFILE" ] || {
	echo >&2 "ERROR: $DOCKERFILE not found"
	exit 1
}

latest="$(bash ./hack/show-latest-releases.sh)"

# Validate all values before touching the Dockerfile
while IFS= read -r line; do
	[[ "$line" =~ ^ARG\ ([A-Z0-9_]+)=(.*)$ ]] || continue
	value="${BASH_REMATCH[2]}"
	if [[ -z "$value" || "$value" == "null" || ! "$value" =~ ^[A-Za-z0-9._+-]+$ ]]; then
		echo >&2 "ERROR: invalid value for ${BASH_REMATCH[1]}: '$value'"
		exit 1
	fi
done <<<"$latest"

updated=0
while IFS= read -r line; do
	[[ "$line" =~ ^ARG\ ([A-Z0-9_]+)=(.*)$ ]] || continue
	name="${BASH_REMATCH[1]}"
	value="${BASH_REMATCH[2]}"
	if ! grep -q "^ARG ${name}=" "$DOCKERFILE"; then
		echo >&2 "WARNING: ARG $name not found in $DOCKERFILE, skipping"
		continue
	fi
	old="$(grep -m1 "^ARG ${name}=" "$DOCKERFILE" | cut -d= -f2-)"
	if [ "$old" != "$value" ]; then
		echo "$name: $old -> $value"
		sed -i -E "s|^ARG ${name}=.*$|ARG ${name}=${value}|" "$DOCKERFILE"
		updated=$((updated + 1))
	fi
	# crictl version is also hardcoded in -ldflags (without the "v" prefix)
	if [ "$name" = "CRI_TOOLS_RELEASE" ]; then
		sed -i -E "s|(sigs\.k8s\.io/cri-tools/pkg/version\.Version=)[^ ]+|\1${value#v}|" "$DOCKERFILE"
	fi
done <<<"$latest"

echo "Updated $updated ARG(s) in $DOCKERFILE"
