#!/usr/bin/env bash
set -euo pipefail

# update-plugin-hashes.sh
# Fetches Jellyfin plugin repository manifests and updates their
# pinned hashes in the nixflix configuration.
#
# Usage:
#   ./scripts/update-plugin-hashes.sh                # update all (from repo root)
#   ./scripts/update-plugin-hashes.sh --check         # check-only, exit 1 if stale
#   nix run .#update-plugin-hashes                    # via flake app
#   nix run .#update-plugin-hashes -- --check          # via flake app (check only)

# Find the repo root — works both from local checkout and nix store
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$SCRIPT_DIR/.git" ] || [ -f "$SCRIPT_DIR/.git" ]; then
	REPO_ROOT="$SCRIPT_DIR"
elif git rev-parse --show-toplevel &>/dev/null 2>&1; then
	REPO_ROOT="$(git rev-parse --show-toplevel)"
elif [ -d "$SCRIPT_DIR/../.git" ] || [ -f "$SCRIPT_DIR/../.git" ]; then
	REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
	echo ":: ERROR: Cannot find nixos-config repo root. Run this script from within the repo."
	exit 1
fi

NIXFILE="$REPO_ROOT/modules/nixos/homelab/services/nixflix.nix"
CHECK_ONLY="${1:-}"

if [ ! -f "$NIXFILE" ]; then
	echo ":: ERROR: nixflix.nix not found at $NIXFILE"
	echo "   Is REPO_ROOT ($REPO_ROOT) correct?"
	exit 1
fi

echo ":: Using config: $NIXFILE"

# Extract all plugin repository URLs from the Nix file
mapfile -t urls < <(grep -n 'url = ' "$NIXFILE" | grep -v '^[^:]*#' | grep -F 'manifest' | sed -E "s/^[0-9]+:.*url = \"([^\"]+)\".*/\1/")
mapfile -t url_lines < <(grep -n 'url = ' "$NIXFILE" | grep -v '^[^:]*#' | grep -F 'manifest' | sed -E 's/^([0-9]+):.*/\1/')

if [ ${#urls[@]} -eq 0 ]; then
	echo ":: No plugin repository URLs found in $NIXFILE"
	exit 0
fi

ALL_MATCHED=true

for i in "${!urls[@]}"; do
	url="${urls[$i]}"
	url_line="${url_lines[$i]}"

	echo ":: Fetching: $url"

	# Download with curl, following redirects, capturing HTTP status
	tmpfile="$(mktemp)"
	http_code="$(curl -sSL -o "$tmpfile" -w "%{http_code}" --max-time 30 "$url" 2>/dev/null || true)"

	if [ "$http_code" != "200" ]; then
		echo "  ⚠  Failed to download (HTTP $http_code), skipping"
		rm -f "$tmpfile"
		ALL_MATCHED=false
		continue
	fi

	# Compute hash in SRI format
	new_hash="$(nix hash file --sri --type sha256 "$tmpfile" 2>/dev/null || {
		sha256_b64="$(openssl dgst -sha256 -binary "$tmpfile" | base64 -w0)"
		echo "sha256-$sha256_b64"
	})"
	rm -f "$tmpfile"

	echo "  Computed hash: $new_hash"

	# Find the hash line that follows this url (within 5 lines)
	hash_line=""
	for offset in 1 2 3 4 5; do
		candidate="$((url_line + offset))"
		candidate_content="$(sed -n "${candidate}p" "$NIXFILE")"
		if echo "$candidate_content" | grep -q 'hash = '; then
			hash_line="$candidate"
			break
		fi
	done

	if [ -z "$hash_line" ]; then
		echo "  ⚠  Could not find hash line after line $url_line, skipping"
		ALL_MATCHED=false
		continue
	fi

	current_hash="$(sed -n "${hash_line}p" "$NIXFILE" | sed -E 's/.*hash = "([^"]+)".*/\1/')"

	if [ "$current_hash" = "$new_hash" ]; then
		echo "  ✓ Hash is current: $current_hash"
	else
		if [ "$CHECK_ONLY" = "--check" ]; then
			echo "  ✗ Hash STALE:"
			echo "    old: $current_hash"
			echo "    new: $new_hash"
			ALL_MATCHED=false
		else
			echo "  → Updating: $current_hash → $new_hash"
			if sed -i "${hash_line}s|\"${current_hash}\"|\"${new_hash}\"|" "$NIXFILE"; then
				echo "  ✓ Updated successfully"
			else
				echo "  ⚠  Failed to update"
				ALL_MATCHED=false
			fi
		fi
	fi
done

echo ""
if [ "$CHECK_ONLY" = "--check" ]; then
	if $ALL_MATCHED; then
		echo ":: All hashes are current."
		exit 0
	else
		echo ":: Some hashes are stale."
		exit 1
	fi
else
	echo ":: Done. Run with --check to verify."
fi
