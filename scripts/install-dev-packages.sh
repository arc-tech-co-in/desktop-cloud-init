#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/devtools-installer.log"

log() {
  local msg="[$(date -Is)] $*"
  echo "$msg"
  # log file if we can
  if [[ -w "$(dirname "$LOG_FILE")" ]] || sudo -n true 2>/dev/null; then
    echo "$msg" | sudo tee -a "$LOG_FILE" >/dev/null || true
  fi
}

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log "This script needs sudo/root. Re-run as: sudo $0"
    exit 1
  fi
}

apt_install() {
  # usage: apt_install pkg1 pkg2 ...
  apt-get update -y
  apt-get install -y --no-install-recommends "$@"
}

cmd_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------
# Installers
# ----------------------------

install_prereqs() {
  log "Installing prerequisites..."
  apt_install ca-certificates curl wget gnupg lsb-release apt-transport-https software-properties-common unzip
}

install_nodejs() {
  # Choose Node major here:
  local nodesource_major="20"  # change to 22 if you want
  if cmd_exists node; then
    log "Node.js already installed: $(node -v)"
    return
  fi

  log "Installing Node.js via NodeSource (${nodesource_major}.x)..."
  curl -fsSL "https://deb.nodesource.com/setup_${nodesource_major}.x" | bash -
  apt_install nodejs
  log "Node.js installed: $(node -v)"
}

install_pnpm() {
  if cmd_exists pnpm; then
    log "pnpm already installed: $(pnpm -v)"
    return
  fi

  if ! cmd_exists corepack; then
    log "corepack not found (should come with modern Node). Skipping pnpm."
    return
  fi

  log "Enabling Corepack and installing pnpm..."
  corepack enable || true
  corepack prepare pnpm@latest --activate || true
  log "pnpm installed: $(pnpm -v || true)"
}

install_bun() {
  if cmd_exists bun; then
    log "bun already installed: $(bun --version || true)"
    return
  fi

  log "Installing bun system-wide to /opt/bun..."
  export BUN_INSTALL="/opt/bun"
  mkdir -p "$BUN_INSTALL"
  curl -fsSL https://bun.com/install | bash

  ln -sf /opt/bun/bin/bun /usr/local/bin/bun

  # make PATH work for interactive shells
  cat >/etc/profile.d/bun.sh <<'EOF'
export BUN_INSTALL=/opt/bun
export PATH="$BUN_INSTALL/bin:$PATH"
EOF

  log "bun installed: $(/usr/local/bin/bun --version || true)"
}

install_uv() {
  if cmd_exists uv; then
    log "uv already installed: $(uv --version || true)"
    return
  fi

  log "Installing uv to /usr/local/bin..."
  curl -LsSf https://astral.sh/uv/install.sh | env \
    UV_INSTALL_DIR="/usr/local/bin" \
    UV_UNMANAGED_INSTALL="1" \
    sh

  log "uv installed: $(uv --version || true)"
}

install_vscode() {
  if cmd_exists code; then
    log "VS Code already installed: $(code --version | head -n 1 || true)"
    return
  fi

  log "Installing VS Code (.deb)..."
  local tmp
  tmp="$(mktemp -d)"
  wget -qO "${tmp}/vscode.deb" "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"
  apt-get update -y
  apt-get install -y "${tmp}/vscode.deb"
  rm -rf "$tmp"
  log "VS Code installed."
}

install_powershell() {
  if cmd_exists pwsh; then
    log "PowerShell already installed: $(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' || true)"
    return
  fi

  local url="https://github.com/PowerShell/PowerShell/releases/download/v7.5.4/powershell_7.5.4-1.deb_amd64.deb"

  log "Installing PowerShell 7.5.4 (.deb from GitHub releases)..."
  local tmp
  tmp="$(mktemp -d)"
  wget -qO "${tmp}/powershell.deb" "$url"
  apt-get update -y
  apt-get install -y "${tmp}/powershell.deb"
  rm -rf "$tmp"
  log "PowerShell installed: $(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' || true)"
}

print_summary() {
  log "---- Summary ----"
  cmd_exists node && log "node: $(node -v)" || log "node: (not installed)"
  cmd_exists pnpm && log "pnpm: $(pnpm -v)" || log "pnpm: (not installed)"
  cmd_exists bun  && log "bun: $(bun --version)" || log "bun: (not installed)"
  cmd_exists uv   && log "uv: $(uv --version)" || log "uv: (not installed)"
  cmd_exists code && log "code: $(code --version | head -n 1)" || log "code: (not installed)"
  cmd_exists pwsh && log "pwsh: $(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')" || log "pwsh: (not installed)"
  log "Log file: $LOG_FILE"
}

main() {
  need_root
  install_prereqs

  # dev stack
  install_nodejs
  install_pnpm
  install_bun
  install_uv
  install_vscode
  install_powershell

  print_summary
  log "Done."
}

main "$@"
