#!/bin/sh

# Exit on errors.
set -e

. ./config.sh

# Convenient bailing.
err() {
	echo "$*" >&2
	exit 1
}

# Set up temporary keyrings for just this import.
export GNUPGHOME=$(mktemp -d)
[ -d "$GNUPGHOME" ] || err "Unable to set up ephemeral keychain for importing."

# Import keys from stdin.
gpg -q --import-options import-minimal --import || err "Error reading provided key."

fp=$(gpg --fingerprint | grep -m 1 '^ *Key fingerprint =' | sed -e 's/^.* = *//' -e 's/ *$//' | tr -dc 0-9A-F)
keyblob=$(gpg -a --no-emit-version --export-options export-minimal --export)

# Clean up the temporary dir.
rm -rf "$GNUPGHOME"

# Save it (ghetto way for now).
echo "$keyblob" > "${key_dir}/${fp}".asc

# Regen the fingerprint HTML & PDF, and party-keyring.
./postprocess.sh

# Tell the user all is good!
cat <<EOF
<!DOCTYPE html>
<html>
<head>
	<title>Thanks for signing up!</title>
</head>
<body>

<p>Thanks for signing up, see you at the event!</p>

</body>
</html>
EOF
