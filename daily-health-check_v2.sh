#!/usr/bin/env bash

set -euo pipefail


TELEGRAM_BOT_TOKEN={{TELEGRAM_BOT_TOKEN}}
TELEGRAM_CHAT_ID={{TELEGRAM_CHAT_ID}}

LOG_FILE="/var/log/zeus-health.log"

PROBLEMS_FOUND=0

DISK_ROOT="/"
DISK_STORAGE="/mnt/storage"

SSD="/dev/sda"
HDD="/dev/sdb"

send_telegram() {

curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
-d chat_id="${TELEGRAM_CHAT_ID}" \
-d text="$1" \
-d parse_mode="HTML" \
> /dev/null 2>&1

}

log() {
echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# ---------------- NETWORK CHECK ----------------

if ! ping -c2 1.1.1.1 > /dev/null 2>&1; then

send_telegram "🚨 <b>NETWORK FAILURE</b>

Zeus server cannot reach the internet.

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi

# ---------------- SMART CHECK ----------------

check_disk() {

DEVICE=$1
TYPE=$2

SMART=$(smartctl -A "$DEVICE")
STATUS=$(smartctl -H "$DEVICE" | grep -i result | awk '{print $6}')

REALLOC=$(echo "$SMART" | grep Reallocated_Sector | awk '{print $10}')
REALLOC=${REALLOC:-0}

TEMP=$(echo "$SMART" | grep -i temperature | head -1 | awk '{print $10}')
TEMP=${TEMP:-0}

if [[ "$STATUS" != "PASSED" || "$REALLOC" -gt 0 ]]; then

send_telegram "⚠️ <b>${TYPE} WARNING</b>

Device: $DEVICE
SMART Status: $STATUS
Reallocated Sectors: $REALLOC
Temp: ${TEMP}°C

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi
}

check_disk "$SSD" "SSD"
check_disk "$HDD" "HDD"

# ---------------- DISK SPACE ----------------

ROOT_USAGE=$(df "$DISK_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
STORAGE_USAGE=$(df "$DISK_STORAGE" | awk 'NR==2 {print $5}' | sed 's/%//')

if [[ "$ROOT_USAGE" -gt 85 || "$STORAGE_USAGE" -gt 85 ]]; then

send_telegram "⚠️ <b>DISK SPACE WARNING</b>

Root: ${ROOT_USAGE}%
Storage: ${STORAGE_USAGE}%

$(df -h $DISK_ROOT $DISK_STORAGE | tail -n +2)

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi

# ---------------- CPU TEMP ----------------

if command -v sensors > /dev/null 2>&1; then

CPU_TEMP=$(sensors | grep "Core 0" | grep -o '[0-9]*\.[0-9]*' | head -1)
CPU_TEMP_INT=${CPU_TEMP%.*}

if [[ -n "$CPU_TEMP_INT" && "$CPU_TEMP_INT" -gt 75 ]]; then

send_telegram "🔥 <b>CPU TEMPERATURE WARNING</b>

CPU Temp: ${CPU_TEMP}°C
Threshold: 75°C

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi
fi

# ---------------- MEMORY CHECK ----------------

MEM_USAGE=$(free | awk '/Mem:/ {printf("%.0f"), $3/$2 * 100}')

if [[ "$MEM_USAGE" -gt 90 ]]; then

send_telegram "💾 <b>HIGH MEMORY USAGE</b>

RAM Usage: ${MEM_USAGE}%

Possible memory leak or runaway service.

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi

# ---------------- DISK I/O ERRORS ----------------

IO_ERRORS=$(dmesg 2>/dev/null | tail -200 | grep -iE "I/O error|EXT4-fs error|Buffer I/O error" | tail -5 || true)

if [[ -n "$IO_ERRORS" ]]; then

send_telegram "🚨 <b>DISK I/O ERRORS DETECTED</b>

Recent kernel disk errors:

<pre>$IO_ERRORS</pre>

Time: $(date '+%Y-%m-%d %H:%M:%S')"

PROBLEMS_FOUND=1

fi

# ---------------- SMART SELF TEST (SUNDAY) ----------------

if [[ $(date +%u) -eq 7 ]]; then

smartctl -t short "$SSD" > /dev/null 2>&1
smartctl -t short "$HDD" > /dev/null 2>&1

send_telegram "🧪 <b>Weekly SMART Self-Test Started</b>

Devices:
$SSD
$HDD

Time: $(date '+%Y-%m-%d %H:%M:%S')"

fi

# ---------------- WEEKLY REPORT ----------------

if [[ $(date +%u) -eq 1 && "$PROBLEMS_FOUND" -eq 0 ]]; then

UPTIME=$(uptime -p)
LOAD=$(uptime | awk -F'load average:' '{print $2}')

RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')

SSD_TEMP=$(smartctl -A "$SSD" | grep -i temperature | head -1 | awk '{print $10}')
HDD_TEMP=$(smartctl -A "$HDD" | grep -i temperature | head -1 | awk '{print $10}')

PING_LATENCY=$(ping -c1 1.1.1.1 | awk -F'=' '/time=/ {print $4}' | awk '{print $1}')

send_telegram "✅ <b>Weekly Zeus Server Health Report</b>

<b>System</b>
• Uptime: $UPTIME
• Load Average:$LOAD

<b>CPU</b>
• Temperature: ${CPU_TEMP:-N/A}°C

<b>Memory</b>
• Used: $RAM_USED / $RAM_TOTAL
• Usage: ${MEM_USAGE}%

<b>Storage</b>
• Root: ${ROOT_USAGE}%
• Storage: ${STORAGE_USAGE}%

<b>Disk Health</b>
• SSD ($SSD): ${SSD_TEMP:-N/A}°C
• HDD ($HDD): ${HDD_TEMP:-N/A}°C

<b>Network</b>
• Latency to Internet: ${PING_LATENCY:-N/A} ms

<b>Status</b>
🟢 All systems operating normally

Time: $(date '+%Y-%m-%d %H:%M:%S')"

fi

log "Health check complete. Problems: $PROBLEMS_FOUND"
