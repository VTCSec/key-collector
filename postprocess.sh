#!/bin/sh

set -e

. ./config.sh

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
	gpg -q -a --export
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
td.uid {
	white-space: normal;
}
th.extend {
	width: 1em;
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
	gpg --fingerprint | awk '
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

	rowspan=(length(uids) > 1 ? " rowspan=\"" length(uids) "\"" : "")
	td="\t<td"
	ctd="</td>"

	fpcell=escape(fp)
	gsub("  ", "<br />", fpcell)

	print "<tr class=\"pub-row\">"
	print td rowspan ">" escape(type) ctd;
	print td rowspan ">" fpcell ctd;
	print td " class=\"uid\">" escape(uids[0]) ctd;
	print td rowspan cb ">" ctd;
	print td rowspan cb ">" ctd;
	print td cb ">" ctd;
	print td cb ">" ctd;
	print "</tr>"

	for (i = 1; i < length(uids); i++) {
		print "<tr class=\"uid-row\">";
		print td " class=\"uid\">" escape(uids[i]) ctd;
		print td cb ">" ctd;
		print td cb ">" ctd;
		print "</tr>";
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
