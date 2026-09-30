# NVCF Log Collector

Collects cluster-level, per-function, and per-node diagnostic data from an NVCF Kubernetes cluster for troubleshooting.

## Prerequisites

- `kubectl` access configured for the target cluster
- SSH access (passwordless/key-based) from the run host to all cluster nodes
- `helm`, `jq`, `python3` installed on the run host
- `crictl` available on each node (used by `collect_crictl.sh`)

## Setup

```bash
git clone https://github.com/ops-shakticloud/nvcf-log-collector.git
cd https://github.com/ops-shakticloud/nvcf-log-collector.git
```

Move both scripts (`collect_logs.sh` and `collect_crictl.sh`) to a common directory preferably on an **NFS path** shared across nodes, so the per-node script (`collect_crictl.sh`) can be invoked via SSH without manual copying.

## Usage

Run from a system where `kubectl` is working:

```bash
mkdir -p <output-dir>
cd <output-dir>
/path/to/collect_logs.sh
```

## What it collects

| Area | Description |
|---|---|
| Cluster-level info | Helm releases/history, NVCFBackend CRs, operator pods |
| Per-function data | Pod describe, container logs, image pull secrets (including decoded auth) |
| NVCA data | Pods, logs, and secrets under `nvca-*` namespaces |
| kube-system data | Pods, logs, and secrets under `kube-system` |
| Per-node logs | `containerd` and `kubelet` journalctl, plus `crictl ps -a` / container logs (via SSH) |

## Output structure

```
<output-dir>/
├── cluster_info/
├── functions/
│   └── <FUNCTION_ID>/
│       ├── k_d_p_ns.<ns>_pod.<pod>.out
│       ├── fid.<id>_ns.<ns>_pod.<pod>_cont.<cont>.out
│       └── fid.<id>_ns.<ns>_pod.<pod>_secretmeta.<secret>.out
├── nvca_data/
├── kube_system_data/
├── <node1>/
│   ├── containerd.journalctl
│   ├── kubelet.journalctl
│   └── crictl_ps_a_<node1>
└── <node2>/
    └── ...
```

## ⚠️ Security Note

This collects **decoded image pull secrets** (including auth tokens). Ensure output is stored securely and shared only with authorized personnel.
