#!/bin/sh
# Generate or retrieve the resident FIDO2 SSH key of the YubiKey.
#   yubikey-key.sh key   generate the key, unless it already exists in SSH_DIR
#                        or on the YubiKey (it is then retrieved instead)
#   yubikey-key.sh dump  retrieve the key from the YubiKey into SSH_DIR
# Variables (set by the Makefile): KEY (key file), KEY_NAME (empty = OpenSSH
# default application "ssh:"), FIDO_DEVICE.
# Idempotent: does nothing if the key file already exists.
set -eu

: "${KEY:?set by the Makefile}"
KEY_NAME=${KEY_NAME:-}
SSH_DIR=$(dirname "$KEY")
APPLICATION="ssh:$KEY_NAME"
RK_FILE="id_ed25519_sk_rk${KEY_NAME:+_$KEY_NAME}"

require_device() {
  FIDO_DEVICE=${FIDO_DEVICE:-$(fido2-token -L 2>/dev/null | head -n1 | cut -d: -f1)}
  [ -n "$FIDO_DEVICE" ] || { echo "No FIDO2 YubiKey detected (fido2-token -L)." >&2; exit 1; }
}

dump() {
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  (cd "$tmp" && ssh-keygen -K -N "")
  if [ ! -f "$tmp/$RK_FILE" ]; then
    echo "$APPLICATION not found on the YubiKey: run \"make key\"." >&2
    exit 1
  fi
  install -d -m 700 "$SSH_DIR"
  install -m 600 "$tmp/$RK_FILE" "$KEY"
  install -m 644 "$tmp/$RK_FILE.pub" "$KEY.pub"
  echo "Installed: $KEY and $KEY.pub"
}

key() {
  echo "Looking for $APPLICATION on the YubiKey (FIDO2 PIN):"
  rps=$(fido2-token -L -r "$FIDO_DEVICE") || { echo "Unable to read resident credentials." >&2; exit 1; }
  if printf '%s\n' "$rps" | grep -qx ".* $APPLICATION"; then
    # Generating again with the same application would overwrite the key on the YubiKey.
    echo "$APPLICATION is already on the YubiKey: retrieving it instead of generating."
    dump
    return
  fi
  install -d -m 700 "$SSH_DIR"
  # Without a name, keep OpenSSH's default comment (user@host).
  ssh-keygen -t ed25519-sk -O resident -O verify-required \
    -O "application=$APPLICATION" ${KEY_NAME:+-C "$KEY_NAME"} -N "" -f "$KEY"
}

case "${1:-}" in
  key|dump)
    [ -f "$KEY" ] && { echo "$KEY already exists: nothing to do."; exit 0; }
    require_device
    "$1"
    ;;
  *)
    echo "Usage: $0 key | dump" >&2
    exit 2
    ;;
esac
