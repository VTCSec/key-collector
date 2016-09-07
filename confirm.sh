#!/bin/sh

# Exit on errors.
set -e

# Convenient bailing.
err() {
	echo "$*" >&2
	exit 1
}

# Escape HTML.
escape() {
	# Order of application of -e is not portable, so we must use separate
	# seds to ensure & escaped before <> so we don't end up with &amp;lt;s
	# on some systems.
	echo "$1" | sed 's/&/\&amp;/g' | sed -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Set up temporary keyrings for just this import.
export GNUPGHOME=$(mktemp -d)
[ -d "$GNUPGHOME" ] || err "Unable to set up ephemeral keychain for importing."

# Import keys from stdin.
gpg -q --import-options import-minimal --import || err "Error reading provided key."

# Ensure we only got one key as a safeguard against someone accidentally trying
# to submit their whole keyring after --exporting without specifying a keyid.
# Also (somewhat) guards against people --exporting with a 32-bit keyid and
# getting their evil32 doppelganger key. https://evil32.com/
count_pubkeys=$(gpg --list-keys | grep ^pub | wc -l | awk '{print $1}')
[ 1 -eq "$count_pubkeys" ] || err "More than one public key provided. Please supply one key at a time. Use gpg --armor --export <your_key_id>"

# Extract the info we need.
fp=$(gpg --fingerprint | grep -m 1 '^ *Key fingerprint =' | sed -e 's/^.* = *//' -e 's/ *$//')
name=$(gpg --list-keys | grep -m 1 ^uid | sed -e 's/^uid *//' -e 's/ *[<(].*//')
info=$(gpg --list-options no-show-keyring --list-keys)
keyblob=$(gpg -a --no-emit-version --export)

# Because --list-options no-show-keyring appears to not work as documented...
info=$(echo "$info" | awk 'BEGIN{pub=0} /^pub/{pub=1} {if(pub)print}')

# Clean up the temporary dir.
rm -rf "$GNUPGHOME"

# Generate some nice HTML output.
cat <<EOF
<!DOCTYPE html>
<html>
<head>
	<title>Confirm key for $(escape "$name")</title>
	<style>
input { font-size: 1.5em; color: white; }
.yes { background: #4c4; }
.no { background: #f00; }
textarea { display: none; }
form { display: inline-block; margin: 1em; }
	</style>
</head>
<body>

<h1>Confirm key for $(escape "$name")</h1>
<h3>$(escape "$fp")</h3>

<p>Are you sure this is the key you intend to have signed? (Check carefully!)</p>
<pre>$(escape "$info")</pre>

<form method="GET" action="/">
	<input type="submit" value="No!" class="no" />
</form>
<form method="POST" action="/add">
	<input type="submit" value="Yes" class="yes" />
	<textarea name="pubkey">$keyblob</textarea>
</form>

</body>
</html>
EOF
