# Server Performance Stats
A simple, portable Bash script to analyze basic server performance statistics on any Linux machine.

## Getting Started
#### 1. Clone the repository
```bash
git clone https://github.com/teves10/server-performance-stats.git
cd server-performance-stats
```

#### 2. Make the script executable
```bash
chmod +x server-stats.sh
```

#### 3. Execute the script
```bash
./server-stats.sh
```

---

### How It Works

The script is divided into sections with simple commands to get system information:

#### CPU Info

```bash
CPU_CORES=$(nproc)
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8 "%"}')
```


`nproc` gets the number of CPU cores.

`top -bn1` gets CPU usage snapshot.


#### Memory Info

```bash
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
MEM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
```


`free -h` shows memory in a human-readable format.

`awk` extracts the values for total, used, and free memory.

#### Disk Info

```bash
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')
```



`df -h /` checks the root filesystem disk usage.

#### Top Processes

```bash
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
```


Lists top 5 CPU-consuming processes (head -n 6 includes header).


This project is part of [roadmap.sh](https://roadmap.sh/projects/server-stats) DevOps projects.
