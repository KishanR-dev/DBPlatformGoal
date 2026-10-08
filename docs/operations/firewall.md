# Linux Netfilter, Firewall Architecture & Packet Filtering Lab

**Project:** DB Platform Engineering Portfolio  
**Target Role:** DevOps Engineer / Platform Engineer — DB Engineering & Consulting GmbH (Job Ref: 585821)  
**Workspace:** `E:\Projects\VSCode\PostOmniroute\DBPlatformGoal`  
**Phase:** Phase 11 — Linux Platform Operations & Troubleshooting Lab  
**Status:** Implemented & Locally Validated  

---

## 1. Linux Netfilter Architecture & Packet Traversal

The Linux kernel implements packet filtering, network address translation (NAT), and packet mangling through the **Netfilter** framework. User-space CLI tools (such as `iptables` and `nftables`) manipulate Netfilter tables in kernel space:

```text
Incoming Packet
      │
      ▼
┌──────────────┐
│  PREROUTING  │ (raw, mangle, nat - DNAT)
└──────┬───────┘
       │
       ├─────────────────────────┐
       ▼ Routing Decision        ▼ (Routed through host)
┌──────────────┐          ┌──────────────┐
│    INPUT     │          │   FORWARD    │ (filter, mangle)
└──────┬───────┘          └──────┬───────┘
       │                         │
       ▼ Local Process           │
┌──────────────┐                 │
│    OUTPUT    │ (raw, mangle,   │
└──────┬───────┘  nat, filter)   │
       │                         │
       ▼ Routing Decision        │
┌──────────────┐                 │
│ POSTROUTING  │◄────────────────┘ (mangle, nat - SNAT / Masquerade)
└──────┬───────┘
       │
       ▼ Outgoing Packet
```

### 1.1 Netfilter Tables & Built-in Chains

| Table | Primary Purpose | Standard Chains |
|---|---|---|
| **`filter`** | Packet filtering and access control (Allow / Drop / Reject). | `INPUT`, `FORWARD`, `OUTPUT` |
| **`nat`** | Network Address Translation (Source NAT, Destination NAT, Port Forwarding). | `PREROUTING`, `OUTPUT`, `POSTROUTING` |
| **`mangle`** | Specialized packet header alterations (TTL, TOS, QoS marks). | `PREROUTING`, `INPUT`, `FORWARD`, `OUTPUT`, `POSTROUTING` |
| **`raw`** | Connection tracking exemption (`NOTRACK` targets). | `PREROUTING`, `OUTPUT` |

---

## 2. Stateful vs. Stateless Packet Filtering

1. **Stateless Filtering:** Evaluates each packet in complete isolation against header parameters (Source IP, Destination IP, Protocol, Port). Faster, but cannot recognize connection context.
2. **Stateful Filtering (`conntrack`):** Uses the Linux connection tracking subsystem to evaluate packets in the context of ongoing sessions:
   - `NEW`: Packet initiating a new connection (e.g. TCP SYN).
   - `ESTABLISHED`: Packet belonging to an already negotiated session (e.g. TCP ACK after handshake).
   - `RELATED`: Packet initiating a secondary connection associated with an existing session (e.g. ICMP error responses).
   - `INVALID`: Packet that cannot be associated with any valid connection state.

---

## 3. Controlled Firewall Laboratory Execution

To safely demonstrate Netfilter packet filtering without risking disruption to the host Windows operating system or corporate VPN connections, the lab executes within an isolated, disposable Docker container with `NET_ADMIN` privileges (`scripts/ops/firewall-check.sh`):

```bash
bash scripts/ops/firewall-check.sh
```

### 3.1 Step-by-Step Lab Execution & Evidence

```text
========================================================================
  DBPlatformGoal — Linux Firewall & Netfilter Packet Filtering Lab
========================================================================
Safety Guarantee: Operating strictly within an ephemeral, isolated container.
Host System Impact: ZERO (Windows Firewall & Host Kernel untouched).

Launching isolated Alpine Linux container with NET_ADMIN capability...

=== STEP 1: Setting up environment & diagnostic tools ===
Installed: iptables (netfilter CLI), curl (HTTP client)

=== STEP 2: Initializing baseline test service on port 8080 ===

=== STEP 3: Baseline ALLOW state verification ===
Querying http://127.0.0.1:8080 (No firewall rules applied)...
Response: ServicePulse-Mock
Result: [ ALLOWED ] Baseline traffic flows successfully.

=== STEP 4: Applying Netfilter / iptables Packet Filtering Rule ===
Command: iptables -A INPUT -p tcp --dport 8080 -j DROP
Current INPUT chain rules:
Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1        0     0 DROP       6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080

=== STEP 5: DENY state verification (Firewall Active) ===
Querying http://127.0.0.1:8080 with firewall DROP rule active (timeout: 2s)...
Result: [ CONNECTION_DROPPED_BY_FIREWALL ] Packet dropped at kernel netfilter boundary as expected.

Inspect packet counters after drop:
    2   120 DROP       6    --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:8080

=== STEP 6: Remediating rule & verifying recovery ===
Command: iptables -D INPUT -p tcp --dport 8080 -j DROP
Querying http://127.0.0.1:8080 after rule removal...
Response: ServicePulse-Mock
Result: [ RECOVERED ] Traffic immediately restored upon rule removal.

=== Isolated Firewall Lab Completed Successfully ===

✓ Linux Netfilter / iptables firewall lifecycle successfully validated.
========================================================================
```

#### Key Technical Observations:
- In **Step 4**, the packet filtering rule `iptables -A INPUT -p tcp --dport 8080 -j DROP` was inserted into the `INPUT` chain.
- In **Step 5**, when the client attempted an HTTP GET connection, the kernel Netfilter engine silently discarded the inbound TCP SYN packets. The iptables packet counter recorded **`2 pkts, 120 bytes`** dropped.
- In **Step 6**, the rule was removed with `iptables -D`, and the TCP handshake and HTTP response were instantly restored.

---

## 4. Host Firewall vs. Kubernetes NetworkPolicy

A critical architectural distinction exists between traditional host firewalls and Kubernetes NetworkPolicies:

```text
┌──────────────────────────────────────────────┬──────────────────────────────────────────────┐
│            HOST FIREWALL (iptables)          │        KUBERNETES NETWORKPOLICY              │
├──────────────────────────────────────────────┼──────────────────────────────────────────────┤
│ Operates at the host / VM kernel layer       │ Declarative API resource (`networking.k8s.io`)│
│ Targets IP addresses, CIDR blocks, ports     │ Targets Pod selectors (`matchLabels`), namespaces│
│ Kernel-enforced (Netfilter / nftables)       │ Enforced ONLY by advanced CNI plugins        │
│ Protects host OS and node-level services     │ Isolates microservice-to-microservice traffic│
└──────────────────────────────────────────────┴──────────────────────────────────────────────┘
```

### 4.1 CNI NetworkPolicy Enforcement Boundary & Limitation

As documented in Phase 6:
- The `kind` cluster utilizes the default `kindnetd` CNI plugin.
- `kindnetd` implements standard bridge routing and basic pod connectivity, but **lacks an enforcing NetworkPolicy eBPF/iptables data plane**.
- While `NetworkPolicy` manifests (`k8s/base/networkpolicy.yaml`) are successfully registered and validated in the Kubernetes API server, active packet-level policy enforcement requires replacing `kindnetd` with an advanced CNI such as **Cilium** or **Calico**.
- *This limitation is explicitly acknowledged and documented to ensure complete technical integrity.*
