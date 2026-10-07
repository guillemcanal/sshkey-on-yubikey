
.DEFAULT_GOAL := help
.DELETE_ON_ERROR:

-include local.mk

KEY_NAME    ?=
SSH_DIR     ?= $(HOME)/.ssh
SSH_CONFIG  ?= $(SSH_DIR)/config
KEY         := $(SSH_DIR)/$(or $(KEY_NAME),id_ed25519_sk)
FIDO_DEVICE ?=
export KEY KEY_NAME FIDO_DEVICE

BIN_DIR     := $(HOME)/.local/bin
UNIT_DIR    := $(HOME)/.config/systemd/user
UNIT        := yubikey-ssh-watch.service
SCRIPTS     := $(BIN_DIR)/ssh-close-masters $(BIN_DIR)/yubikey-ssh-watch
PKGS        := openssh-client libfido2-1 fido2-tools udev

sed_escape   = $(subst |,\|,$(subst &,\&,$(subst \,\\,$1)))

.PHONY: help check key dump pubkey config service install status uninstall

help: ## Show this help
	@awk 'BEGIN { FS = ":.*## " } /^[a-z-]+:.*## / { printf "  %-15s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check: ## Check that the required binaries are available
	@missing=; for b in ssh ssh-keygen fido2-token udevadm systemctl; do \
	  command -v $$b >/dev/null || { echo "Missing: $$b"; missing=1; }; \
	done; \
	if [ -n "$$missing" ]; then echo "→ sudo apt install $(PKGS)"; exit 1; fi; \
	echo "Binaries: OK"

key: check ## Generate the key on the YubiKey if absent, then install it in ~/.ssh
	@scripts/yubikey-key.sh key

dump: check ## Retrieve the key from the YubiKey into ~/.ssh if absent
	@scripts/yubikey-key.sh dump

pubkey: ## Print the public key (to register on GitHub and servers)
	@cat "$(KEY).pub"

config: ## Install the github.com block (key + persistent connection) in ~/.ssh/config
	@sed 's|@KEY@|$(call sed_escape,$(KEY))|g' ssh/config | scripts/ssh-config-block.sh install - "$(SSH_CONFIG)"

$(BIN_DIR)/%: bin/%
	@install -D -m 755 $< $@ && echo "Installed: $@"

# The watcher runs continuously: restart it when it changes.
# ssh-close-masters is run afresh on each removal: no restart needed.
$(BIN_DIR)/yubikey-ssh-watch: bin/yubikey-ssh-watch
	@install -D -m 755 $< $@ && echo "Installed: $@"
	@systemctl --user try-restart $(UNIT) 2>/dev/null || true

$(UNIT_DIR)/$(UNIT): systemd/$(UNIT)
	@install -D -m 644 $< $@ && echo "Installed: $@"
	@systemctl --user daemon-reload
	@systemctl --user try-restart $(UNIT) 2>/dev/null || true

service: $(SCRIPTS) $(UNIT_DIR)/$(UNIT) ## Install and enable the user service (no root)
	@systemctl --user is-enabled --quiet $(UNIT) && systemctl --user is-active --quiet $(UNIT) \
	  && echo "$(UNIT): already active." \
	  || { systemctl --user enable --now $(UNIT) && echo "$(UNIT): enabled."; }

install: key config service ## Install everything: key, ~/.ssh/config and user service

status: ## Show status: key, YubiKey, service, github.com connection
	@printf 'Key        : '; ssh-keygen -lf "$(KEY).pub" 2>/dev/null || echo "missing ($(KEY).pub)"
	@printf 'YubiKey    : '; fido2-token -L 2>/dev/null | grep . || echo "not detected"
	@printf 'Service    : '; systemctl --user is-active $(UNIT) 2>/dev/null || true
	@printf 'github.com : '; ssh -O check github.com 2>&1 || true

uninstall: ## Remove service, scripts and config block (keys and YubiKey left untouched)
	@systemctl --user disable --now $(UNIT) 2>/dev/null || true
	@rm -fv $(UNIT_DIR)/$(UNIT) $(SCRIPTS)
	@systemctl --user daemon-reload
	@scripts/ssh-config-block.sh remove "$(SSH_CONFIG)"
