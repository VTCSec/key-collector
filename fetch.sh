#!/bin/sh

# Exit on errors.
set -e

. ./config.sh

# Conveniently error out.
err() {
	echo "$*" >&2
	exit 1
}

[ -n "$keyserver" ] || err "Config file missing keyserver."

# Ensure we were passed a fingerprint.
[ $# -eq 1 -a -n "$1" ] || err "No fingerprint provided. Please provide your full 20-byte fingerprint."

# Validate well-formed fingerprint.
fp=$(echo "$1" | head -1 | tr a-f A-F | tr -dc 0-9A-F)
echo "$fp" | grep -qE '^[0-9A-F]{40}$' || err "Invalid fingerprint format. Please provide your full 20-byte fingerprint."

# Set up temporary keyrings for just this import.
export GNUPGHOME=$(mktemp -d)
[ -d "$GNUPGHOME" ] || err "Unable to set up ephemeral keychain for importing."

# Fetch the key
gpg --keyserver "$keyserver" --recv-key "$fp" >/dev/null 2>&1 \
|| err "Unable to find key ${fp} on the keyserver. Please double-check the fingerprint or submit the exported key itself."

# Dump the key we just fetched.
gpg --armor --export-options export-minimal --no-emit-version --export "$fp"

# Clean up the temporary dir.
rm -rf "$GNUPGHOME"
