#!/usr/bin/env bash


set -o pipefail
export LC_ALL=C

# --------------------

hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }
title() { echo; hr; echo "$1"; hr; }
have() { command -v "$1" >/dev/null 2>&1; }

human() {
  awk -v b="$1" 'function H(x){s="B KiB MiB GiB TiB PiB EiB ZiB YiB";
    for(i=1;x>=1024 && i<9;i++) x/=1024; printf("%.1f %s", x, substr(s,i*4-3,5))}
    BEGIN{H(b)}'
}

percent() {

  awk -v p="$1" -v w="$2" 'BEGIN{ if (w==0) print "0.0"; else printf "%.1f", (p/w)*100 }'
}

# --------------------
HOST="$(hostname)"
NOW="$(date -u '+%Y-%m-%d %H:%M:%SZ')"
echo "Server Performance Stats for: $HOST  (UTC now: $NOW)"

# --------------------
title "System"
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS="${PRETTY_NAME:-$NAME}"
else
  OS="$(uname -sr)"
fi
KERNEL="$(uname -r)"
ARCH="$(uname -m)"
echo "OS:      $OS"
echo "Kernel:  $KERNEL"
echo "Arch:    $ARCH"

# --------------------
UPTIME_HUMAN="$(uptime -p 2>/dev/null || true)"
LOAD_AVG="$(awk '{print $1" "$2" "$3}' /proc/loadavg 2>/dev/null)"
[ -n "$UPTIME_HUMAN" ] && echo "Uptime:  $UPTIME_HUMAN"
[ -n "$LOAD_AVG" ] && echo "Load:    $LOAD_AVG (1m 5m 15m)"

# --------------------
title "CPU"
read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 g1 gn1 < /proc/stat
idle1=$(( i1 + w1 ))
nonidle1=$(( u1 + n1 + s1 + q1 + sq1 + st1 ))
total1=$(( idle1 + nonidle1 ))

sleep 1

read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 g2 gn2 < /proc/stat
idle2=$(( i2 + w2 ))
nonidle2=$(( u2 + n2 + s2 + q2 + sq2 + st2  ))
total2=$(( idle2 + nonidle2 ))

idle_d=$(( idle2 - idle1 ))
total_d=$(( total2 - total1 ))

CPU_PCT=$(awk -v idle="$idle_d" -v total="$total_d" 'BEGIN{ if (total==0) print "0.0"; else printf "%.1f", (1-idle/total)*100 }')
CPU_CORES="$(grep -c ^processor /proc/cpuinfo 2>/dev/null || nproc 2>/dev/null || echo "?")"
echo "Cores:   $CPU_CORES"
echo "Usage:   $CPU_PCT % "

# --------------------
title "Memory"
MTOTAL_kB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
MAVAIL_kB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
MUSED_kB=$(( MTOTAL_kB - MAVAIL_kB ))
MPCT=$(percent "$MUSED_kB" "$MTOTAL_kB")

echo "Total:   $(human $((MTOTAL_kB*1024)))"
echo "Used:    $(human $((MUSED_kB*1024))) ($MPCT %)"
echo "Free*:   $(human $((MAVAIL_kB*1024))) "

# --------------------
title "Disk (aggregate)"
if df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay --total >/dev/null 2>&1; then
  read -r DTOTAL DUSED DAVAIL DUSEP <<<"$(df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay --total | awk '/^total/ {print $2, $3, $4, $5}')"
else
  read -r DTOTAL DUSED DAVAIL <<<"$(df -B1 -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR>1 {t+=$2; u+=$3; a+=$4} END{print t, u, a}')"
  DUSEP="$(awk -v u="$DUSED" -v t="$DTOTAL" 'BEGIN{ if (t==0) print "0%"; else printf "%.0f%%", (u/t)*100 }')"
fi
echo "Total:   $(human "$DTOTAL")"
echo "Used:    $(human "$DUSED") ($DUSEP)"
echo "Free:    $(human "$DAVAIL")"
echo
echo "By mount point:"
df -h -x tmpfs -x devtmpfs -x squashfs -x overlay | awk 'NR==1 || NR>1 {printf "%-25s %8s %8s %8s %6s  %s\n", $6, $2, $3, $4, $5, $1}'

# --------------------
title "Top 5 processes by CPU"
if have ps; then
  ps -eo pid,ppid,comm,%cpu,%mem --sort=-%cpu | awk 'NR==1{printf "%-7s %-7s %-25s %6s %6s\n",$1,$2,$3,$4,$5; next} NR<7{printf "%-7s %-7s %-25s %6s %6s\n",$1,$2,$3,$4,$5}'
else
  echo "ps not found"
fi

title "Top 5 processes by Memory"
if have ps; then
  ps -eo pid,ppid,comm,%cpu,%mem --sort=-%mem | awk 'NR==1{printf "%-7s %-7s %-25s %6s %6s\n",$1,$2,$3,$4,$5; next} NR<7{printf "%-7s %-7s %-25s %6s %6s\n",$1,$2,$3,$4,$5}'
fi

# --------------------
title "Users"
LOGGED_IN_N=$(who 2>/dev/null | wc -l | tr -d ' ')
if [ -n "$LOGGED_IN_N" ] && [ "$LOGGED_IN_N" -gt 0 ]; then
  echo "Logged-in users ($LOGGED_IN_N):"
  who | awk '{printf " - %-12s tty:%-8s from:%s at %s %s\n", $1, $2, ($6=="" ? "-" : $6), $3, $4}'
else
  echo "No one is currently logged in via a TTY."
fi

# --------------------
title "Security (failed login attempts, last 24h)"
FAILED_COUNT="N/A"
DETAIL_SOURCE=""
if have lastb && [ -r /var/log/btmp ]; then
  FAILED_COUNT="$(lastb | grep -vE 'btmp begins|^$' | wc -l | tr -d ' ')"
  DETAIL_SOURCE="(via lastb, all-time count)"
elif have journalctl; then
  FAILED_COUNT="$(journalctl -q -o cat -p warning -S '24 hours ago' 2>/dev/null | grep -cE 'Failed password|authentication failure' || true)"
  DETAIL_SOURCE="(via journalctl, last 24h)"
fi
echo "Failed login attempts: ${FAILED_COUNT} ${DETAIL_SOURCE}"

# --------------------
if have ss; then
  title "Network (listening ports)"
  ss -ltn '( sport >= :1 )' 2>/dev/null | awk 'NR==1{print; next} {printf "%-5s %-22s %-22s %s\n",$1,$4,$5,$6}' | head -n 15
fi