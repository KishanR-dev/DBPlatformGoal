# Linux Systems Administration & Troubleshooting Guide

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Operating System & Kernel Foundation

The primary platform operations environment is hosted on **Ubuntu 26.04.1 LTS (Resolute Raccoon)** running under the 64-bit Linux kernel (`6.18.33.2-microsoft-standard-WSL2`).

### 1.1 OS & Kernel Identification Commands

```bash
# Display kernel version, architecture, and build metadata
uname -srm
# Output: Linux 6.18.33.2-microsoft-standard-WSL2 x86_64

# Inspect official distribution metadata
cat /etc/os-release
# Output:
# PRETTY_NAME="Ubuntu 26.04.1 LTS"
# NAME="Ubuntu"
# VERSION_ID="26.04"
# VERSION="26.04.1 LTS (Resolute Raccoon)"
# ID=ubuntu
# ID_LIKE=debian
```

---

## 2. CPU Architecture & Load Average Dynamics

### 2.1 Hardware Architecture (`lscpu`)

```text
Architecture:            x86_64
CPU op-mode(s):          32-bit, 64-bit
Address sizes:           39 bits physical, 48 bits virtual
Byte Order:              Little Endian
CPU(s):                  12
On-line CPU(s) list:     0-11
Model name:              Intel(R) Core(TM) i7-8750H CPU @ 2.20GHz
Thread(s) per core:      2
Core(s) per socket:      6
Socket(s):               1
```

### 2.2 System Uptime & Load Averages (`uptime`)

```bash
uptime
# Output: 12:03:25 up 5:41, 2 users, load average: 1.34, 0.82, 0.68
```

#### Load Average Interpretation for SREs & Platform Engineers:
- **1.34 (1 min), 0.82 (5 min), 0.68 (15 min):** The load average represents the average number of processes in a **Runnable (`R`)** or **Uninterruptible Disk Sleep (`D`)** state over time.
- Across a **12-core CPU**, a load average of 1.34 represents approximately **11.1% CPU saturation** ($1.34 / 12 = 0.111$).
- A load average equal to the core count (12.0) represents 100% capacity without queueing. A load average $> 12.0$ indicates process queueing and scheduling latency.

---

## 3. Memory Subsystem & Virtual Memory Management

### 3.1 Memory Allocation Analysis (`free -m`)

```text
               total        used        free      shared  buff/cache   available
Mem:           15912        2769        6922         102        6403       13142
Swap:           4096           0        4096
```

#### Key Metric Distinctions:
1. **Total (15,912 MiB):** Total physical memory allocated to the Linux guest.
2. **Used (2,769 MiB):** Memory actively allocated by application processes and the kernel.
3. **Free (6,922 MiB):** Completely unallocated memory (not yet used for buffering/caching).
4. **Buff/Cache (6,403 MiB):** Memory utilized by the kernel for disk cache (Page Cache) and filesystem buffer heads. *This memory is immediately reclaimable by application workloads when needed.*
5. **Available (13,142 MiB):** The true operational metric indicating how much memory can be allocated without causing swap thrashing (`Free + Reclaimable Cache - Kernel Slop`).
6. **Swap (4,096 MiB total, 0 MiB used):** Zero swap utilization confirms healthy physical memory headroom without paging pressure.

---

## 4. Storage & Filesystem Hierarchy

### 4.1 Filesystem Utilization (`df -h`)

```text
Filesystem      Size  Used Avail Use% Mounted on
/dev/sde       1007G  2.9G  953G   1% /
none            7.8G     0  7.8G   0% /dev
none            7.8G     0  7.8G   0% /run
none            7.8G     0  7.8G   0% /run/lock
none            7.8G     0  7.8G   0% /run/shm
```

### 4.2 Inode Utilization Analysis (`df -i`)

```bash
df -i /
# Output:
# Filesystem      Inodes  IUsed   IFree IUse% Mounted on
# /dev/sde       66977792 108392 66869400    1% /
```
*Platform Insight:* A filesystem can experience an "Out of Space" error even with gigabytes of free storage if inode exhaustion occurs (e.g. millions of tiny log files). The system maintains 66.8M free inodes (1% used).

---

## 5. Process Lifecycle & Resource Inspection

Linux processes transition through well-defined lifecycle states governed by the kernel scheduler:

```text
                ┌──────────────┐
                │ Created/Fork │
                └──────┬───────┘
                       │
       ┌───────────────▼───────────────┐
       │     TASK_RUNNING (R)          │◄─────────────┐
       │ (Executing or in Run Queue)   │              │
       └───────┬───────────────▲───────┘              │
               │               │                      │
     Wait for  │               │ Event /              │ Interruptible
     Resource  │               │ Data Ready           │ Wakeup
               │               │                      │
       ┌───────▼───────────────┴───────┐      ┌───────┴───────┐
       │ TASK_UNINTERRUPTIBLE (D)      │      │ TASK_INTERR.  │
       │ (Disk I/O / Hardware Wait)    │      │      (S)      │
       └───────────────┬───────────────┘      └───────────────┘
                       │ Exit / Termination
               ┌───────▼───────────────┐
               │    EXIT_ZOMBIE (Z)    │ (Parent has not called waitpid)
               └───────┬───────────────┘
                       │ Parent reaps status
               ┌───────▼───────────────┐
               │       DEAD (X)        │
               └───────────────────────┘
```

### 5.1 Deep Process Inspection via `/proc` Filesystem

The `/proc` virtual filesystem provides direct visibility into kernel process tables.

```bash
# Example: Inspecting process PID 1 (systemd)
./scripts/ops/process-diagnostics.sh --pid 1
```

```text
========================================================================
  Detailed Process Diagnostics: PID 1 (systemd)
========================================================================
  Process Name    : systemd
  State           : S (sleeping)
  Parent PID (PPID): 0
  Thread Count    : 1
  UID / GID       : Real UID: 0 | GID: 0
  Resident Mem (RSS): 15996 kB
  Virtual Mem (VSZ) : 24696 kB
  Swap Consumed   : 0 kB
  Open FDs Count  : N/A (requires root for PID 1)
  FD Limits       : 2147483584 (soft) / 2147483584 (hard)
  Command Line    : /sbin/init
```

### 5.2 File Descriptors & System Limits (`/proc/<pid>/limits`)

Every open network socket, file, pipe, and UNIX domain socket consumes one File Descriptor (FD).
- **Soft Limit:** The current maximum number of FDs a process can open (modifiable by process up to hard limit).
- **Hard Limit:** The absolute ceiling enforceable by the kernel (modifiable only by root/capabilities).
- **Diagnostic Command:** `ls -1 /proc/<PID>/fd | wc -l` vs `grep "Max open files" /proc/<PID>/limits`.

---

## 6. Systemd & Journald Platform Inspection

```bash
# Verify systemd initialization state
systemctl is-system-running
# Output: running

# Inspect recent kernel and systemd journal events
journalctl -n 10 --no-pager
```

```text
Oct 08 11:50:30 DESKTOP-DP7RBSE kernel: vethe7b80f3 (unregistering): left promiscuous mode
Oct 08 11:50:30 DESKTOP-DP7RBSE kernel: docker0: port 1(vethe7b80f3) entered disabled state
Oct 08 11:50:33 DESKTOP-DP7RBSE systemd-resolved[68]: Clock change detected. Flushing caches.
```
