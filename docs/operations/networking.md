# Platform Networking Fundamentals & Diagnostics Guide

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Network Interface Topology & IP Allocation

In modern containerized Linux systems, multiple virtual and physical network interfaces coexist to route packets between host namespaces, containers, and Kubernetes pods:

```text
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             LINUX NETWORK TOPOLOGY                               │
├──────────────────────────────────────────────────────────────────────────────────┤
│  lo (127.0.0.1/8)       : Loopback interface for local inter-process sockets     │
│  eth0 (172.26.80.78/20) : Primary virtual NIC bridging WSL2 to Windows Host vSwitch│
│  docker0 (172.17.0.1/16): Linux bridge interface connecting local Docker containers │
│  vethXXXXX              : Virtual Ethernet pair bridging container/pod namespaces │
└──────────────────────────────────────────────────────────────────────────────────┘
```

### 1.1 Interface Inspection (`ip -br addr`)

```bash
ip -br addr
```

```text
lo               UNKNOWN        127.0.0.1/8 10.255.255.254/32 ::1/128 
eth0             UP             172.26.80.78/20 fe80::215:5dff:fe13:dbe/64 
docker0          DOWN           172.17.0.1/16 
```

- **`lo` (Loopback):** Localhost socket routing.
- **`eth0`:** Assigned IP `172.26.80.78/20` in the WSL2 virtual network.
- **`docker0`:** Default Docker bridge network.

---

## 2. Kernel Routing Tables & Packet Forwarding

### 2.1 Route Table Inspection (`ip route`)

```bash
ip route show
```

```text
default via 172.26.80.1 dev eth0 proto kernel 
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown 
172.26.80.0/20 dev eth0 proto kernel scope link src 172.26.80.78 
```

#### Routing Logic:
1. **Local Subnet Traffic (`172.26.80.0/20`):** Routed directly out interface `eth0` with source IP `172.26.80.78`.
2. **Container Bridge Traffic (`172.17.0.0/16`):** Routed to `docker0` bridge.
3. **Default Route (`0.0.0.0/0` via `172.26.80.1`):** All external non-local traffic is forwarded to the default gateway (`172.26.80.1`), which bridges to the host physical network adapter.

---

## 3. DNS Resolution Architecture

DNS resolution operates across a hierarchical resolver chain:

```text
Application Process (e.g. curl / Python)
  │
  ▼
/etc/resolv.conf  ──────────► nameserver 10.255.255.254 (WSL2 Host Resolver)
  │                                     │
  │                                     ▼
  │                           Windows Host DNS / Corporate DNS
  │
(Inside Kubernetes Pod)
  │
  ▼
/etc/resolv.conf  ──────────► nameserver 10.96.0.10 (CoreDNS ClusterIP)
                                        │
                                        ▼
                            Kubernetes CoreDNS Engine
                                ├── servicepulse.servicepulse.svc.cluster.local -> 10.96.139.109
                                └── External queries -> Forward to upstream host DNS
```

### 3.1 DNS Query Diagnostics (`getent` & `curl`)

```bash
# Resolve standard domain
getent ahosts localhost
# Output: 127.0.0.1 STREAM localhost

# Resolve external domain
getent ahosts google.com
# Output: 142.250.183.174 STREAM
```

---

## 4. Socket States & TCP State Machine

```text
              ┌───────────────┐
              │    CLOSED     │
              └───────┬───────┘
                      │ Passive Open (bind + listen)
              ┌───────▼───────┐
              │    LISTEN     │◄─────────────────────────────┐
              └───────┬───────┘                              │
                      │ Receive SYN                          │
              ┌───────▼───────┐                              │
              │   SYN_RCVD    │                              │
              └───────┬───────┘                              │
                      │ Receive ACK                          │
              ┌───────▼───────┐                              │
              │  ESTABLISHED  │                              │
              └───────┬───────┘                              │
                      │ Close Connection (FIN / ACK)         │
              ┌───────▼───────┐                              │
              │   TIME_WAIT   │──────────────────────────────┘
              └───────────────┘ (Wait 2*MSL to ensure clean teardown)
```

### 4.1 Socket Inspection via `ss`

```bash
ss -tuln
```

```text
Netid State  Recv-Q Send-Q  Local Address:Port  Peer Address:Port
tcp   LISTEN 0      4096        127.0.0.1:58918      0.0.0.0:*   
tcp   LISTEN 0      4096        127.0.0.1:34431      0.0.0.0:*   
tcp   LISTEN 0      1000   10.255.255.254:53         0.0.0.0:*   
tcp   LISTEN 0      4096       127.0.0.54:53         0.0.0.0:*   
tcp   LISTEN 0      4096    127.0.0.53%lo:53         0.0.0.0:*   
```

- **`58918` / `34431`:** Forwarded ports for the `db-platform-tf` and `db-platform` Kubernetes API servers.
- **`53`:** `systemd-resolved` local caching stub listeners on `127.0.0.53` and `127.0.0.54`.

---

## 5. Kubernetes End-to-End Networking Path

The network path connecting a client to the ServicePulse application pod traverses five distinct stages:

```text
1. Client (Curl / Ingress)
   │ Query: http://servicepulse:80/health
   ▼
2. CoreDNS Resolution
   │ servicepulse.servicepulse.svc.cluster.local -> 10.96.139.109 (ClusterIP)
   ▼
3. Kubernetes Service (ClusterIP: 10.96.139.109, Port: 80/TCP)
   │ iptables / kube-proxy DNAT Translation
   ▼
4. Endpoint Allocation (EndpointSlice / Endpoints)
   │ Maps ClusterIP:80 -> Pod IP: 10.244.1.8:8000
   ▼
5. Pod Container Network Interface (veth / eth0 in pod netns)
   │ Enters container namespace
   ▼
6. ServicePulse Application (Uvicorn / FastAPI listening on 0.0.0.0:8000)
```

---

## 6. Controlled Network Failure Scenarios & Diagnostics

To validate operational diagnostic capability, three distinct network failure conditions were evaluated:

### Scenario 1: Valid In-Cluster Service Reachability
- **Command:** `curl -s http://servicepulse/health`
- **Result:** **HTTP 200 OK** (Payload: `{"status":"healthy","version":"1.4.0",...}`).

### Scenario 2: Target Port Misdirection / Port Down
- **Command:** `curl -s --connect-timeout 2 http://servicepulse:8081/health`
- **Result:** **Connection Refused / Timeout (`CURLE_OPERATION_TIMEDOUT` exit code 28 / `CURLE_COULDNT_CONNECT` exit code 7)**.
- **Diagnostic Finding:** Service is registered and DNS resolves, but no process is listening on the destination port.

### Scenario 3: Non-Existent Service / DNS Lookup Failure
- **Command:** `curl -s --connect-timeout 2 http://invalid-service-name.servicepulse/health`
- **Result:** **`CURLE_COULDNT_RESOLVE_HOST` (exit code 6)**.
- **Diagnostic Finding:** CoreDNS returns `NXDOMAIN` for the requested domain name.
