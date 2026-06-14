#!/usr/bin/env bash
# zork MCP launcher (Claude Code plugin).
#
# Ensures the verified `zork` binary is present in the plugin's data dir, then
# execs it as the stdio MCP server. The binary is downloaded from dl.zork.app and
# checksum-verified — never `curl | bash`, nothing runs unseen. It self-updates:
# at most once a day it checks the published version and refreshes if newer
# (best-effort and offline-safe — a cached binary always wins if the net is down).
#
# Opt-out knobs (env):
#   ZORK_PIN=<version>   pin to an exact version; never auto-update off it.
#   ZORK_NO_UPDATE=1     never auto-update; run whatever is cached.
#   ZORK_CHECK_INTERVAL  seconds between update checks (default 86400 = daily).
#
# stdout is the MCP JSON-RPC stream — all diagnostics MUST go to stderr.
set -euo pipefail

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:${PATH:-}"

DATA="${CLAUDE_PLUGIN_DATA:?CLAUDE_PLUGIN_DATA is not set (run me via the plugin)}"
BIN_DIR="$DATA/bin"
BIN="$BIN_DIR/zork"
VER_FILE="$BIN_DIR/.version"
STAMP="$BIN_DIR/.lastcheck"
DL="${ZORK_DL:-https://dl.zork.app}"
CHECK_INTERVAL="${ZORK_CHECK_INTERVAL:-86400}"   # seconds between update checks

log() { printf 'zork-plugin: %s\n' "$*" >&2; }

asset_name() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64|Linux-amd64) echo "zork-linux-x64" ;;
    Darwin-*)                 echo "zork-macos-arm64" ;;
    *) return 1 ;;
  esac
}

# download <version> <asset>  — fetch + sha256-verify into $BIN, record version.
download() {
  local ver="$1" asset="$2" tmp want got
  tmp="$(mktemp -d)"
  curl -fsSL "$DL/v$ver/$asset"     -o "$tmp/$asset"     || { rm -rf "$tmp"; return 1; }
  curl -fsSL "$DL/v$ver/SHA256SUMS" -o "$tmp/SHA256SUMS" || { rm -rf "$tmp"; return 1; }
  want="$(awk -v a="$asset" '$2==a {print $1}' "$tmp/SHA256SUMS" || true)"
  if command -v sha256sum >/dev/null 2>&1; then got="$(sha256sum "$tmp/$asset" | awk '{print $1}')"
  else got="$(shasum -a 256 "$tmp/$asset" | awk '{print $1}')"; fi
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    log "CHECKSUM MISMATCH for $asset — refusing"; rm -rf "$tmp"; return 1
  fi
  install -m 0755 "$tmp/$asset" "$BIN"
  printf '%s' "$ver" > "$VER_FILE"
  rm -rf "$tmp"
}

ensure() {
  mkdir -p "$BIN_DIR"
  local asset
  asset="$(asset_name)" || { log "unsupported platform $(uname -s)-$(uname -m) — see https://zork.app"; exit 1; }
  local cur; cur="$(cat "$VER_FILE" 2>/dev/null || echo '')"

  # First launch: install is required and must succeed.
  if [ ! -x "$BIN" ]; then
    local ver
    if [ -n "${ZORK_PIN:-}" ]; then ver="$ZORK_PIN"
    else ver="$(curl -fsSL "$DL/VERSION")" || { log "cannot reach $DL"; exit 1; }; fi
    log "first launch — fetching zork v$ver ($asset), verified..."
    download "$ver" "$asset" || { log "install failed"; exit 1; }
    date +%s > "$STAMP"
    log "installed → $BIN"
    return 0
  fi

  # Pinned: ensure cached == pin, else switch. No clock, no VERSION call.
  if [ -n "${ZORK_PIN:-}" ]; then
    if [ "$cur" != "$ZORK_PIN" ]; then
      log "pin: switching zork ${cur:-?} → $ZORK_PIN..."
      download "$ZORK_PIN" "$asset" || log "pin fetch failed — keeping v${cur:-?}"
    fi
    return 0
  fi

  # Updates disabled: run whatever is cached.
  [ "${ZORK_NO_UPDATE:-0}" = "1" ] && return 0

  # Existing install: throttled, best-effort self-update (offline-safe).
  local now last; now="$(date +%s)"; last="$(cat "$STAMP" 2>/dev/null || echo 0)"
  if [ $(( now - last )) -ge "$CHECK_INTERVAL" ]; then
    local latest
    latest="$(curl -fsSL "$DL/VERSION" 2>/dev/null || true)"
    if [ -n "$latest" ]; then
      date +%s > "$STAMP"
      if [ "$latest" != "$cur" ]; then
        log "updating zork ${cur:-?} → $latest..."
        download "$latest" "$asset" || log "update failed — keeping v${cur:-?}"
      fi
    fi
    # net down → keep the cached binary; retry next interval
  fi
}

ensure
exec "$BIN" "$@"
