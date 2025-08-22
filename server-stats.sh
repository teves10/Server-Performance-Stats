#!/bin/bash

set -o pipefail
export LC_ALL=C

hr() { printf '%*s\n' "${COLUMNS:-80}" '' | tr ' ' -; }
title() { echo; hr; echo "$1"; hr; }
have() { command -v "$1" >/dev/null 2>&1; }

title " Server Performance Stats"

HOST="$(hostname)"
NOW="$(date -u '+%Y-%m-%d %H:%M:%S')"
echo "Server Performance Stats for: $HOST  (UTC now: $NOW)"


title " System"

echo "  Uptime: $(uptime -p)"
echo "  Load Average: $(uptime | awk -F'load average:' '{ print $2 }')"
echo "  OS Version: $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "  Kernel: $(uname -r)"
echo "  Logged in Users: $(who | wc -l)"
echo "  Failed Login Attempts (last 24h):" 
sudo lastb -s -1days 1>/dev/null | wc -l || echo "  (Cannot access lastb)"
echo ""


title " CPU Usage:"
CPU_CORES=$(nproc) 
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8 "%"}')  
echo "  Total CPU cores: $CPU_CORES"
echo "  CPU usage: $CPU_USAGE"
echo ""


title "  Memory Usage:"
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
MEM_USED_PERCENT=$(free | awk '/^Mem:/ {printf("%.2f%%", $3/$2*100)}')
MEM_FREE_PERCENT=$(free | awk '/^Mem:/ {printf("%.2f%%", $4/$2*100)}')
echo "  Total memory: $MEM_TOTAL"
echo "  Used memory: $MEM_USED ($MEM_USED_PERCENT)"
echo "  Free memory: $MEM_FREE ($MEM_FREE_PERCENT)"
echo ""


title "  Disk Usage:"
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
DISK_USED_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
echo "  Total disk space: $DISK_TOTAL"
echo "  Used disk space: $DISK_USED ($DISK_USED_PERCENT)"
echo "  Available disk space: $DISK_AVAIL"
echo ""



title "  Top 5 Processes by CPU Usage:"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
echo ""


title "  Top 5 Processes by Memory Usage:"
ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 6
echo ""





title "          End of Report             "

