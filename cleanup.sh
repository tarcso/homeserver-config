#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Must run as root" >&2
  exit 1
fi

# ── helpers ────────────────────────────────────────────────────────────────────
bytes_to_human() {
  local b=$1
  if   (( b >= 1073741824 )); then printf "%.2f GB" "$(echo "scale=2; $b/1073741824" | bc)"
  elif (( b >= 1048576    )); then printf "%.2f MB" "$(echo "scale=2; $b/1048576"    | bc)"
  elif (( b >= 1024       )); then printf "%.2f KB" "$(echo "scale=2; $b/1024"       | bc)"
  else printf "%d B" "$b"
  fi
}

disk_free() { df / --output=avail -B1 | tail -1 | tr -d ' '; }

LOG="/var/log/cleanup.log"
TOTAL_BEFORE=$(disk_free)
TS="$(date '+%Y-%m-%d %H:%M:%S')"

log() { echo "$1" | tee -a "$LOG"; }

log ""
log "═══════════════════════════════════════════════"
log "  Cleanup run — $TS"
log "═══════════════════════════════════════════════"
log "Disk free before: $(bytes_to_human "$TOTAL_BEFORE")"
log ""

# ── docker prune ───────────────────────────────────────────────────────────────
log "── Docker system prune ──"
BEFORE=$(disk_free)
PRUNE_OUT=$(docker system prune -af --filter "until=720h" 2>&1)
AFTER=$(disk_free)
FREED=$(( AFTER - BEFORE ))

# extract what was removed from docker output
echo "$PRUNE_OUT" | grep -E "^(Deleted|Untagged|Total reclaimed)" | while read -r line; do
  log "  $line"
done
log "  → Freed: $(bytes_to_human "$FREED")"
log ""

# ── volume prune ───────────────────────────────────────────────────────────────
log "── Docker volume prune ──"
BEFORE=$(disk_free)
VOL_OUT=$(docker volume prune -f 2>&1)
AFTER=$(disk_free)
FREED=$(( AFTER - BEFORE ))

echo "$VOL_OUT" | grep -E "^(Deleted|Total reclaimed)" | while read -r line; do
  log "  $line"
done
log "  → Freed: $(bytes_to_human "$FREED")"
log ""

# ── container logs ─────────────────────────────────────────────────────────────
log "── Container log truncation ──"
BEFORE=$(disk_free)
LOG_COUNT=0
LOG_SIZE_BEFORE=0

while IFS= read -r -d '' f; do
  size=$(stat -c%s "$f" 2>/dev/null || echo 0)
  LOG_SIZE_BEFORE=$(( LOG_SIZE_BEFORE + size ))
  (( LOG_COUNT++ ))
  truncate -s 0 "$f"
done < <(find /var/lib/docker/containers -name "*-json.log" -print0 2>/dev/null)

log "  Truncated $LOG_COUNT log file(s)"
log "  → Freed: $(bytes_to_human "$LOG_SIZE_BEFORE")"
log ""

# ── apt clean ─────────────────────────────────────────────────────────────────
log "── APT clean ──"
BEFORE=$(disk_free)
apt-get clean > /dev/null 2>&1
AFTER=$(disk_free)
FREED=$(( AFTER - BEFORE ))
log "  → Freed: $(bytes_to_human "$FREED")"
log ""

# ── apt autoremove ─────────────────────────────────────────────────────────────
log "── APT autoremove ──"
BEFORE=$(disk_free)
AR_OUT=$(apt-get autoremove -y 2>&1)
AFTER=$(disk_free)
FREED=$(( AFTER - BEFORE ))

echo "$AR_OUT" | grep -E "^(Removing|Purging)" | while read -r line; do
  log "  $line"
done
log "  → Freed: $(bytes_to_human "$FREED")"
log ""

# ── summary ───────────────────────────────────────────────────────────────────
TOTAL_AFTER=$(disk_free)
TOTAL_FREED=$(( TOTAL_AFTER - TOTAL_BEFORE ))

log "═══════════════════════════════════════════════"
log "  Disk free after:  $(bytes_to_human "$TOTAL_AFTER")"
log "  Total freed:      $(bytes_to_human "$TOTAL_FREED")"
log "  Log saved to:     $LOG"
log "═══════════════════════════════════════════════"
