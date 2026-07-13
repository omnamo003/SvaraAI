# ShivaAI Production Deployment Specification
**Module 10**  

---

## 1. High Availability Production Architecture

ShivaAI starts as a Docker Compose cluster on a Virtual Private Server (VPS) and scales to a multi-node Kubernetes cluster.

```
                         [Internet Requests]
                                  |
                                  v (TLS Port 443)
                      +-----------------------+
                      |   Cloudflare / DNS    |
                      +-----------------------+
                                  |
                                  v
                      +-----------------------+
                      |  Nginx Load Balancer  |
                      +-----------------------+
                                  |
            +---------------------+---------------------+
            | (Round Robin)                             |
            v                                           v
+-----------------------+                   +-----------------------+
|    Application Node   |                   |    Application Node   |
|                       |                   |                       |
|   +---------------+   |                   |   +---------------+   |
|   |  svara-web    |   |                   |   |  svara-web    |   |
|   +---------------+   |                   |   +---------------+   |
|   +---------------+   |                   |   +---------------+   |
|   | svara-backend |   |                   |   | svara-backend |   |
|   +---------------+   |                   |   +---------------+   |
+-----------------------+                   +-----------------------+
            |                                           |
            +---------------------+---------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
|                         Data & Queue Layer                        |
|                                                                   |
|   +---------------+  +-------------------+  +-----------------+   |
|   | PostgreSQL    |  | Redis Cluster     |  | MinIO / Ceph    |   |
|   | (Primary/Repl)|  | (Broker & Cache)  |  | (S3 Storage)    |   |
|   +---------------+  +-------------------+  +-----------------+   |
+-------------------------------------------------------------------+
                                  ^
                                  |
+-------------------------------------------------------------------+
|                        GPU Worker Pool                            |
|                                                                   |
|   +--------------------------+    +--------------------------+    |
|   | GPU Worker 01            |    | GPU Worker 02            |    |
|   | (Celery - CUDA XTTS)     |    | (Celery - CUDA XTTS)     |    |
|   +--------------------------+    +--------------------------+    |
+-------------------------------------------------------------------+
```

---

## 2. Infrastructure Expansion & Scaling Roadmap

### Phase 1: Local & VPS (Single Machine)
* **Hosts**: 1 VPS (Ubuntu 22.04, 8 Core CPU, 32GB RAM, optional 1x NVIDIA T4 GPU).
* **Stack**: Docker Compose. External networks expose only Nginx on port 80/443. Databases persist via named Docker volumes.

### Phase 2: Multi-Host Deployment
* **Hosts**: 2 API/Web nodes + 1 Database node + 2 Dedicated GPU Worker nodes.
* **Stack**: Docker swarm / Nomad. DB migrates to a managed provider (e.g. AWS RDS or Supabase). Redis queues run on a separate cache instance.

### Phase 3: Cloud Native Cluster
* **Hosts**: Kubernetes managed nodes (EKS / GKE).
* **Stack**: Helm, ArgoCD, Celery workers auto-scale dynamically using Kubernetes KEDA based on queue backlog metrics in Redis.

---

## 3. Monitoring & Observability Architecture

We implement a complete monitoring stack using **Prometheus** and **Grafana**:

* **Metrics Scraper**: Prometheus pulls metrics from:
  1. `/api/v1/metrics` (FastAPI Prometheus exporter mapping API latency, error rates, active connections).
  2. `cadvisor`: Docker container metrics (CPU, Memory, IO).
  3. `node_exporter`: Host system telemetry.
  4. `celery-prometheus-exporter`: Worker queue processing delays.
* **Alerting Rules**: Slack and PagerDuty notifications are triggered if:
  * Backend API error rate (HTTP 5xx) > 1% in a 5-minute sliding window.
  * Worker queue backlog > 100 jobs.
  * GPU memory utilization > 95% for over 10 consecutive minutes.

---

## 4. Disaster Recovery & Backup Strategy

ShivaAI maintains a **3-2-1 backup strategy** for databases and objects:

1. **Active Replica**: PostgreSQL runs standard active-standby streaming replication to a secondary replica host.
2. **Daily Snapshots**: Cron jobs execute database backups and upload encrypted `.sql` files:
   - Tooling: `pg_dump` compressed.
   - Storage target: Remote AWS S3 bucket (separate region).
3. **MinIO Object Retention**: MinIO runs a bucket replication policy sending copy writes of audio/voice data to a secondary MinIO storage server in a different geographical zone.
4. **Recovery Time Objective (RTO)**: Under 2 hours.
5. **Recovery Point Objective (RPO)**: Under 1 hour.

---

## 5. Deployment Security Checklist

- [ ] Disable all plain HTTP access. Enforce TLS 1.3 only using Let's Encrypt certificates.
- [ ] Block external ports for Postgres (`5432`), Redis (`6379`), MinIO API (`9000`), and Backend API (`8000`). Only Nginx (`80/443`) should be exposed.
- [ ] Run Docker containers in non-root mode (`USER app` in Dockerfiles).
- [ ] Deploy Vault or AWS Secrets Manager to inject environment keys at runtime (do not write values in Compose files).
- [ ] Enforce SSH authentication keys only for server management (disable standard password SSH logins).
- [ ] Run daily security audits using vulnerability scanners (Trivy / Snyk) on Docker base images.
