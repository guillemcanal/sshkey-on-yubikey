#!/bin/sh
# Manage an "ssh-yubikey" marked block at the top of an ssh_config file.
#   ssh-config-block.sh install <block-file | -> <ssh-config>
#   ssh-config-block.sh remove <ssh-config>
# Idempotent: the file is only rewritten when its content changes.
set -eu

MARKER=ssh-yubikey
BEGIN="# BEGIN $MARKER (managed by make config, do not edit)"
END="# END $MARKER"

usage() {
  echo "Usage: $0 install <block-file | -> <ssh-config> | remove <ssh-config>" >&2
  exit 2
}

# Strip the marked block and leading blank lines.
strip() {
  [ -f "$1" ] || return 0
  awk -v begin="# BEGIN $MARKER" -v end="$END" '
    index($0, begin) == 1  { skip = 1; next }
    index($0, end) == 1    { skip = 0; next }
    skip                   { next }
    !started && /^[ \t]*$/ { next }
                           { started = 1; print }
  ' "$1"
}

# Write $2 to $1 only if the content differs.
write_if_changed() {
  if [ -f "$1" ] && printf '%s' "$2" | cmp -s - "$1"; then
    echo "$1: already up to date."
    return
  fi
  [ -d "$(dirname "$1")" ] || install -d -m 700 "$(dirname "$1")"
  tmp=$(mktemp "$1.XXXXXX")
  printf '%s' "$2" > "$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$1"
  echo "$1: updated."
}

case "${1:-}" in
  install)
    [ $# -eq 3 ] || usage
    # Read the block first, so that set -e catches a failing cat.
    block=$(cat "$2")
    [ -n "$block" ] || { echo "Empty block, $3 left untouched." >&2; exit 1; }
    rest=$(strip "$3")
    write_if_changed "$3" "$BEGIN
$block
$END
${rest:+
$rest
}"
    ;;
  remove)
    [ $# -eq 2 ] || usage
    [ -f "$2" ] || { echo "$2: missing, nothing to do."; exit 0; }
    rest=$(strip "$2")
    write_if_changed "$2" "${rest:+$rest
}"
    ;;
  *) usage ;;
esac
