#!/bin/sh
# Wrapper for the bundled rtl-daemon MCP server binary.
# The binary ships gzipped; decompress it on first run, then exec it.
# Nothing may be written to stdout -- it is the MCP stdio channel.
set -eu

DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
BIN="$DIR/rtl-daemon-mcp"
GZ="$BIN.gz"

if [ ! -f "$BIN" ] && [ -f "$GZ" ]; then
    TMP=$(mktemp "$BIN.XXXXXX")
    trap 'rm -f "$TMP"' EXIT
    gunzip -c "$GZ" > "$TMP"
    chmod 755 "$TMP"
    mv -f "$TMP" "$BIN"
    trap - EXIT
    rm -f "$GZ"
fi

# Belt and braces: the exec bit can be lost by a copy, an archive, or a
# checkout that did not preserve modes.
[ -f "$BIN" ] && chmod +x "$BIN" 2>/dev/null || true

if [ ! -x "$BIN" ]; then
    echo "rtl-daemon-mcp: no executable at $BIN and no $GZ to unpack" >&2
    exit 1
fi

exec "$BIN"
