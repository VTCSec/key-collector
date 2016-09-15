#!/bin/sh

set -e

. ./config.sh

# Convenient bailing.
err() {
	echo "$*" >&2
	exit 1
}

[ -n "$html_form" ] || err "Config file missing html_form."
[ -n "$pdf_form" ] || err "Config file missing pdf_form."
[ -n "$key_dir" ] || err "Config file missing key_dir."
[ -n "$party_ring" ] || err "Config file missing party_ring."

make_pdf() {
	# Drops some table lines when rendering tables with border-collapse.
	# xvfb-run wkhtmltopdf -s Letter -l - "$1"

	# Positions things slightly differently than browsers, but worked
	# around with @media.
	weasyprint - "$1" # page too narrow
}

export GNUPGHOME=$(mktemp -d)

setup() {
	find "$key_dir" -type f -name '*.asc' -exec gpg -q --import {} +
}

make_keyring() {
	gpg -q --export
}

cleanup() {
	rm -rf "$GNUPGHOME"
}

header() {
cat <<EOF
<!DOCTYPE html>
<html>
<head>
	<title>VTCSec / Rackspace Key-Signing Party</title>
	<style>
h1 {
	text-align: center;
}
table {
	margin-top: 5em;
	font-family: monospace;
	border-spacing: 0;
	border-collapse: collapse;
	width: 100%;
}
th, td {
	white-space: nowrap;
	text-align: center;
}
td.uid {
	text-align: left;
}
td {
	border: 2px solid black;
	padding: 3px;
}
td.fp {
	width: 15em;
}
td.uid {
	white-space: normal;
}
th.extend {
	width: 1.5em;
	height: 1.5em;
	position: relative;
	margin-right: 0px;
}
th.extend div {
	position: absolute;
	bottom: 0;
	right: 50%;
	vertical-align: bottom;
	text-align: right;
	width: 0;
	height: 0;
}
.u1, .u2, .u3, .u4 {
	border-top: 1px solid black;
	border-right: 1px solid black;
	position: absolute;
	display: inline-block;
	bottom: 0;
	right: 0;
}
.u1 {	height: .5em; width: 0.5em; }
.u2 {	height: 1.5em; width: 0.5em; }
.u3 {	height: 2.5em; width: 0.5em; }
.u4 {	height: 3.5em; width: 0.5em; }
.root {
	position: relative;
	left: 0;
	top: 0;
	height: 0;
	width: 0;
}
.shift {
	position: absolute;
	right: .75em;
	top: -.75em;
}

@page {
	size: Letter;

	@bottom-right {
		content: "Page " counter(page) " / " counter(pages);
	}
}
@media print {
	body {
		width: 150%;
		transform: scale(.75) translate(-23%, -30%);
	}
	.u1, .u2, .u3, .u4 {
		bottom: -.5em;
	}
	.shift {
		margin-top: -.75em;
		right: .25em;
		top: 0;
	}
}
	</style>
</head>
<body>

<h1>VTCSec / Rackspace Key-Signing Party</h1>

<table> <thead> <tr>
	<th>Type</th>
	<th>Fingerprint</th>
	<th>UID(s)</th>
	<th class="extend"><div><span class="u1"><span class="root"><span class="shift">Fingerprint verified?</span></span></span></div></th>
	<th class="extend"><div><span class="u2"><span class="root"><span class="shift">Identity verified?</span></span></span></div></th>
	<th class="extend"><div><span class="u3"><span class="root"><span class="shift">Key signed?</span></span></span></div></th>
	<th class="extend"><div><span class="u4"><span class="root"><span class="shift">Signature mailed or uploaded?</span></span></span></div></th>
</tr> </thead> <tbody>
EOF
}

body() {
	gpg --fingerprint | gawk '
function escape(s) {
	gsub("&", "\\&amp;", s);
	gsub("<", "\\&lt;", s);
	gsub(">", "\\&gt;", s);
	return s;
}

BEGIN {
	type = "";
	fp="";
	split("", uids);

	split("", keys);
}
	
/^pub / {
	# grab key type
	split($2, a, "/");
	type = a[1];

	# clear fingerprint and UIDs
	fp = "";
	split("", uids);
}

/^ *Key fingerprint = / {
	sub(/^.*= */, "");
	fp = $0;
}

/^uid / {
	sub(/^uid */, "");
	if ($0 !~ /^\[jpeg image/)
		uids[length(uids)] = $0;
}

/^$/ {
	# key finished
	keys[fp]["type"] = type;
	for (i in uids) {
		keys[fp]["uids"][i] = uids[i];
	}
}

function primary_uid_strcmp(i1, v1, i2, v2) {
	k1 = toupper(v1["uids"][0]) i1
	k2 = toupper(v2["uids"][0]) i2
	if (k1 > k2) return 1;
	if (k2 < k1) return -1;
	return 0;
}

END {
PROCINFO["sorted_in"] = "primary_uid_strcmp";
for (fp in keys) {
	rowspan=(length(keys[fp]["uids"]) > 1 ? " rowspan=\"" length(keys[fp]["uids"]) "\"" : "")
	td="\t<td"
	ctd="</td>"

	fpcell=escape(fp)
	gsub("  ", "<br />", fpcell)

	print "<tr class=\"pub-row\">"
	print td rowspan ">" escape(keys[fp]["type"]) ctd;
	print td rowspan " class=\"fp\">" fpcell ctd;
	print td " class=\"uid\">" escape(keys[fp]["uids"][0]) ctd;
	print td rowspan cb ">" ctd;
	print td rowspan cb ">" ctd;
	print td cb ">" ctd;
	print td cb ">" ctd;
	print "</tr>"

	for (i = 1; i < length(keys[fp]["uids"]); i++) {
		print "<tr class=\"uid-row\">";
		print td " class=\"uid\">" escape(keys[fp]["uids"][i]) ctd;
		print td cb ">" ctd;
		print td cb ">" ctd;
		print "</tr>";
	}
}
}
'
}

footer() {
cat <<EOF
</tbody> </table>

</body>
</html>
EOF
}

setup

make_keyring > "$party_ring"

{
	header
	body
	footer
} | tee "$html_form" | make_pdf "$pdf_form"

cleanup
