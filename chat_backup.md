# ShivaAI (Svara AI) Project State & Architectural Backup
**Last Updated**: July 14, 2026  

This file serves as a comprehensive manifest of the current project state, active configurations, completed modules, and the developmental roadmap of ShivaAI, prepared as a master reference backup.

---

## 1. Project Context & Philosophy
* **Project Name**: ShivaAI (Workspace folder: `Svara AI`)
* **Mission**: Build a production-ready AI Voice Platform featuring Text-to-Speech (TTS), Zero-Shot Voice Cloning, and real-time streaming capabilities.
* **Stack**: Next.js 14, FastAPI, PostgreSQL (with pgvector), Redis, MinIO (S3 compatible), Celery, Docker Compose, Nginx.

---

## 2. Progress & Completed Milestones

### Module 1: Project Architecture Specification
* **Status**: **Completed (Design Only)**
* **Deliverable**: [project_architecture_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/project_architecture_spec.md)
* **Scope**: Defines directory organization, Docker networks overlay layout, database ER model, REST/WS API patterns, coding standard lints, and Git workflows.

### Module 2: Development Environment Configuration
* **Status**: **Completed & Verified**
* **Deliverable**: [development_environment_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/development_environment_spec.md)
* **Configs Configured**:
  - [.gitignore](file:///d:/AI%20Projects/Websites/Svara%20AI/.gitignore): Root exclusions for virtual environments and package caches.
  - [.vscode/settings.json](file:///d:/AI%20Projects/Websites/Svara%20AI/.vscode/settings.json): Auto-format rules on save.
  - [.vscode/extensions.json](file:///d:/AI%20Projects/Websites/Svara%20AI/.vscode/extensions.json): Recommended IDE plugins list.
  - [.vscode/launch.json](file:///d:/AI%20Projects/Websites/Svara%20AI/.vscode/launch.json): Launch profiles for local runs and debugpy remote container hooks.
  - [ruff.toml](file:///d:/AI%20Projects/Websites/Svara%20AI/ruff.toml) & [.prettierrc](file:///d:/AI%20Projects/Websites/Svara%20AI/.prettierrc): Shared linting/formatting rules.
  - [run.ps1](file:///d:/AI%20Projects/Websites/Svara%20AI/run.ps1): Unified PowerShell management wrapper CLI.
  - [DEVELOPER_SETUP.md](file:///d:/AI%20Projects/Websites/Svara%20AI/DEVELOPER_SETUP.md): Bootstrapping guide.

### Module 3: Authentication & Authorization Design
* **Status**: **Completed (Design Only)**
* **Deliverable**: [authentication_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/authentication_spec.md)
* **Scope**: Access tokens, Refresh Token Rotation (RTR), session tracking schemas, and SaaS multi-tenant RBAC permissions matrix.

### Modules 4–10: Platform Systems Design Specs
* **Status**: **Completed (Design Only)**
* **Deliverables**:
  - [dashboard_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/dashboard_spec.md) (Module 4)
  - [tts_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/tts_spec.md) (Module 5)
  - [voice_library_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/voice_library_spec.md) (Module 6)
  - [voice_cloning_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/voice_cloning_spec.md) (Module 7)
  - [api_platform_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/api_platform_spec.md) (Module 8)
  - [billing_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/billing_spec.md) (Module 9)
  - [deployment_spec.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/deployment_spec.md) (Module 10)

### Master Revisions & Backlog Specs
* **Status**: **Completed & Approved**
* **Deliverables**:
  - [revised_architecture.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/revised_architecture.md): CTO-level audit fixes covering HNSW `pgvector` indexes, Redis Pub/Sub WebSocket event backplanes, token-bucket quota checks, and consent liveness verification blocks.
  - [project_roadmap.md](file:///d:/AI%20Projects/Websites/Svara%20AI/docs/architecture/project_roadmap.md): Complete task list with dependencies, acceptance criteria, and story point efforts.

---

## 3. Active System Verification State
The docker container stack is running and verified healthy:
* **svara-backend**: Rebuilt successfully using clean, uncached dependency layers. Successfully boots FastAPI server.
* **svara-nginx**: Correctly routes traffic.
* **Health Check API**: Tested and operational:
  ```powershell
  curl.exe -s http://127.0.0.1/api/health
  # Output: {"status":"ok"}
  ```
* **svara-web**: Running React client via Next.js server (returns HTTP 200).
* **svara-worker**: Connected to Redis broker and successfully listening for TTS tasks.

---

## 4. WSL & Docker disk-space recovery guides
If the host C drive is full due to Docker images:
1. Run system prune inside workspace terminal:
   ```powershell
   docker stop $(docker ps -a -q)
   docker system prune -a --volumes -f
   docker builder prune -a -f
   ```
2. Compact WSL virtual disk (`ext4.vhdx`) using Windows `diskpart` utility.
3. Move WSL storage VM to another drive with space (e.g., `D:`) using `wsl --export` and `wsl --import`.
