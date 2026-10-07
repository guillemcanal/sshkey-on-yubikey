# SSH key on Yubikey

**Goal:** use an SSH key stored on a YubiKey for GitHub, without a PIN and touch prompt on every Git command.

The key is generated inside the YubiKey and never leaves it. The PIN and touch open a persistent connection to GitHub once; that connection is closed as soon as the YubiKey is unplugged.

```mermaid
---
config:
  themeCSS: |
    * {
      --node-bg: #e0f2fe;
      --node-border: #0284c7;
      --node-text: #0c4a6e;
      --line: #64748b;
      --label-bg: #ffffff;
      --label-text: #334155;
      --cluster-border: #d0d7de;
      --cluster-title: #57606a;
      --accent: #bc4c00;
      --shadow: rgba(185, 185, 185, 1);
    }

    @media (prefers-color-scheme: dark) {
      * {
        --node-bg: #0c4a6e;
        --node-border: #38bdf8;
        --node-text: #e0f2fe;
        --line: #8b98a9;
        --label-bg: #1e293b;
        --label-text: #e2e8f0;
        --cluster-border: #30363d;
        --cluster-title: #8b949e;
        --accent: #f0883e;
        --shadow: rgba(0, 0, 0, 0.6);
      }
    }

    .node rect,
    .node path,
    .node polygon,
    .node circle {
      fill: var(--node-bg) !important;
      stroke: var(--node-border) !important;
    }

    .nodeLabel,
    .node .label {
      color: var(--node-text) !important;
    }

    .flowchart-link {
      stroke: var(--line) !important;
    }

    .marker,
    .marker path {
      fill: var(--line) !important;
      stroke: var(--line) !important;
    }

    .edgeLabel,
    .edgeLabel p,
    .labelBkg {
      background-color: var(--label-bg) !important;
      color: var(--label-text) !important;
    }

    .edgeLabel p {
      padding: 3px 8px;
      border-radius: 4px;
    }

    .edgeLabel rect {
      fill: var(--label-bg) !important;
      opacity: 1 !important;
    }

    .cluster rect {
      fill: none !important;
      stroke: var(--cluster-border) !important;
      filter: none !important;
    }

    .cluster-label span,
    .cluster span {
      color: var(--cluster-title) !important;
    }

    [data-look="neo"].node rect,
    [data-look="neo"].node polygon,
    [data-look="neo"].node circle,
    [data-look="neo"].node .outer-path {
      filter: drop-shadow(1px 2px 2px var(--shadow)) !important;
    }

    path[data-id^="removal"] {
      stroke: var(--accent) !important;
      stroke-width: 1.5px !important;
    }

    .label[data-id^="removal"] p {
      color: var(--accent) !important;
    }
---
flowchart LR
  subgraph install["Install: make install"]
    key@{ shape: rounded, label: "make key" }
    keyfile@{ shape: doc, label: "~/.ssh/KEY_NAME" }
    config@{ shape: rounded, label: "make config" }
    sshconfig@{ shape: doc, label: "~/.ssh/config<br/>Host github.com" }
    service@{ shape: rounded, label: "make service" }
    watch@{ shape: rounded, label: "yubikey-ssh-watch<br/>systemd --user" }
  end
  subgraph usage["Usage: git push / pull"]
    git@{ shape: rounded, label: "git push / pull" }
    open@{ shape: diamond, label: "connection<br/>open?" }
    pin@{ shape: rounded, label: "prompt for PIN + touch<br/>on the YubiKey" }
    master@{ shape: rounded, label: "master connection<br/>to github.com" }
  end
  subgraph removal["YubiKey removal"]
    removed@{ shape: circle, label: "YubiKey<br/>removed" }
    close@{ shape: rounded, label: "ssh-close-masters" }
  end

  key -->|generates or retrieves| keyfile
  config -->|adds the block| sshconfig
  service -->|enables| watch
  git -->|checks| open
  open -->|no| pin
  pin -->|opens| master
  open -->|yes| master
  removed removal1@-. "signals (udev)" .-> watch
  watch removal2@-. "runs" .-> close
  close removal3@-. "closes" .-> master
```

## Prerequisites

Check prerequisites with `make check`

## Quick start

```bash
# generate a new key + update ~/.ssh/config + register a user service
make install   
```

`make help` lists the other targets.

## Change the key name

`KEY_NAME` sets the file in `~/.ssh` and the FIDO *application* under which the key is stored on the YubiKey:

| `KEY_NAME`         | File                   | FIDO application |
|--------------------|------------------------|------------------|
| *(empty, default)* | `~/.ssh/id_ed25519_sk` | `ssh:`           |
| `work`             | `~/.ssh/work`          | `ssh:work`       |

To set it on a machine, create `local.mk` (not versioned):

```make
KEY_NAME = work
```

## Deploy the public key

Examples use the default name (replace `id_ed25519_sk` with `KEY_NAME` if set):

```bash
gh ssh-key add ~/.ssh/id_ed25519_sk.pub --title yubikey   # GitHub
ssh-copy-id -i ~/.ssh/id_ed25519_sk.pub user@host         # Server (OpenSSH ≥ 8.4)
```
