# ShivaAI (Svara AI) Local Development Environment Setup Guide

This guide details the architecture, standards, and step-by-step procedures to establish a complete, professional, and reproducible local development environment for ShivaAI.

---

## 1. System Requirements & Prerequisites

To ensure cross-system compatibility (especially for Windows developers), all developers must install the following core requirements:

| Component | Target Version | Purpose |
| :--- | :--- | :--- |
| **WSL2 (Windows Subsystem for Linux)** | Ubuntu 22.04 LTS+ | Native Linux runtime virtualization under Windows |
| **Docker & Docker Desktop** | v25.0.0+ (with Compose v2+) | Multi-container system orchestration & service isolation |
| **Node.js** | v20.x (LTS) | Local package installation and Next.js testing |
| **Python** | v3.10.x | Virtual environment typechecking and local script utility |
| **VS Code** | Latest Release | IDE Workspace standard |

### Windows WSL2 Configurations
Ensure WSL2 is configured to prevent memory leaks and reserve adequate CPU cores for local containers. Add the following to `C:\Users\<YourUsername>\.wslconfig`:
```ini
[wsl2]
memory=8GB     # Limits VM memory allocation
processors=4   # Limits virtual CPU usage
guiApplications=false
```

---

## 2. Directory & Folder Organization

ShivaAI follows a monorepo structure separating core services but maintaining uniform settings at the workspace root:

```
/svara-ai                      # Workspace Root
  ├── .vscode/                 # IDE workspace configurations
  │     ├── settings.json      # Workspace format-on-save and path rules
  │     ├── launch.json        # Debugger configs (FastAPI, Next.js, Celery)
  │     └── extensions.json    # Standard recommended plugins
  ├── backend/                 # FastAPI Application (API Gateway)
  │     ├── app/               # Application code
  │     └── requirements.txt   # Backend python packages
  ├── worker/                  # Celery worker (Speech Synthesis / Voice Cloner)
  │     ├── app/               # Task definitions and model loaders
  │     └── requirements.txt   # Worker python packages
  ├── web/                     # Next.js 14 Frontend Application
  │     ├── src/               # React and hooks code
  │     └── package.json       # Web dependency manifest
  ├── nginx/                   # Nginx Reverse Proxy
  │     └── nginx.conf         # Gateway request router
  ├── .gitignore               # Root git exclusions
  ├── .env.example             # Template env config
  ├── docker-compose.yml       # Local compose orchestrator
  ├── docker-compose.override.yml.example # Optional container debug config
  ├── ruff.toml                # Shared Python linting rules
  ├── .prettierrc              # Shared JS/TS/CSS/Markdown format rules
  └── run.ps1                  # PowerShell helper CLI
```

---

## 3. Environment Variables Strategy (.env)

We utilize a **single-source-of-truth** environment file at the root directory level.
* **`.env`** is ignored by Git and must **never** be committed. It contains local development secrets and configuration values.
* **`.env.example`** is committed to git. When a developer joins or when environment settings change, `.env.example` is updated.

### Bootstrapping your Local `.env`
Run this command at the root to create your local `.env` copy:
```powershell
Copy-Item .env.example .env
```
Key variables configuration inside `.env`:
* `DATABASE_URL`: Connection string mapping `postgres` host inside docker network.
* `REDIS_URL`: Message broker queue address.
* `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`: Object storage credentials.
* `JWT_SECRET`: Local key used to sign web authorization tokens.

---

## 4. Docker Compose Local Architecture

Docker compose orchestrates seven isolated services inside a bridge overlay network named `svara-network`.

```
                  +--------------------------------+
                  |         svara-nginx            |
                  |          (Port 80)             |
                  +--------------------------------+
                                  |
               +------------------+------------------+
               | (Routes to /)                       | (Routes to /api)
               v                                     v
      +------------------+                 +------------------+
      |    svara-web     |                 |  svara-backend   |
      |   (Port 3000)    |                 |   (Port 8000)    |
      +------------------+                 +------------------+
                                                     |
             +------------------+--------------------+------------------+
             |                  |                    |                  |
             v                  v                    v                  v
    +------------------+ +--------------+ +--------------------+ +--------------------+
    |  svara-postgres  | | svara-redis  | |    svara-minio     | |    svara-worker    |
    |   (Port 5432)    | | (Port 6379)  | | (Ports 9000/9001)  | |  (Celery Process)  |
    +------------------+ +--------------+ +--------------------+ +--------------------+
```

### Exposed Gateway Ports
Only two services expose ports to your Windows/host interface:
1. `svara-nginx` (**Port 80**): Serves the frontend at `http://localhost/` and forwards `/api/*` requests to the FastAPI backend.
2. `svara-minio` (**Port 9001**): Exposes the MinIO Console Web GUI for object storage bucket administration.

---

## 5. Coding Standards, Linting, & Formatting

To ensure clean coding practices, formatting is enforced on every file save inside VS Code.

### Python Rules (Ruff)
Ruff is used for linting and formatting. Rules are declared in the root [ruff.toml](file:///d:/AI%20Projects/Websites/Svara%20AI/ruff.toml):
* Code style matches **Black** specifications (line length: 88).
* Automatic import sorting (**isort** style rules).
* Code rules: Pycodestyle (`E`, `W`), Pyflakes (`F`), Pep8-naming (`N`), Flake8-bugbear (`B`).

### JS / TS / CSS Rules (Prettier & ESLint)
* Standard formatter: Prettier (defined in [.prettierrc](file:///d:/AI%20Projects/Websites/Svara%20AI/.prettierrc)).
* Rules include double quotes (`"doubleQuotes"`), 100 character width limits, trailing commas, and semicolons.
* Next.js uses ESLint to check for React specific optimization warnings on compile.

---

## 6. Git Branching & Workflow Strategy

We enforce a **Semantic Git Workflow** mapped to three logical environments:

```
[main]               # Production-ready release branch (Fully audited & verified)
  ^
  | Pull Request
[develop]            # Shared staging / integration branch (Automatic CI tests run here)
  ^
  | Branch & Merge
[feature/*]          # Active developer task branches (e.g. feature/voice-cloning)
[bugfix/*]           # Active bugfixes (e.g. bugfix/auth-jwt-expiration)
```

### Commit Style Convention
We use **Semantic Commit Messages**:
* `feat: add voice-cloning Celery pipeline`
* `fix: repair JWT auth user validation parse error`
* `docs: update setup guide documentation`
* `refactor: extract MinIO boto3 client initialization`
* `test: add unit tests for job model status updates`

---

## 7. Local File Storage Strategy

ShivaAI utilizes MinIO to emulate Amazon S3 storage locally. Data is stored in two persistent containers:
1. `svara-voices`: Contains reference voice samples and PyTorch speaker embeddings (`.pth` / `.npy`).
2. `svara-audio`: Contains generated TTS waveforms (`.wav`).

### Volume Mounting Strategy
Local folders are mounted to containers in development:
* `./backend:/app` and `./worker:/app`: Enables hot-reloading. Changes to your local files immediately execute inside containers.
* **Persistent Docker Volumes**: `postgres_data`, `redis_data`, and `minio_data` preserve DB logs and audio files even if you stop or rebuild containers.

---

## 8. Debugging Workflow

Debugging FastAPI and Celery code inside docker containers is achieved using `debugpy` (Python Debugging Protocol).

### Setup Remote Container Debugging
1. Copy the debug override compose file:
   ```powershell
   cp docker-compose.override.yml.example docker-compose.override.yml
   ```
2. Start the stack:
   ```powershell
   .\run.ps1 start
   ```
   This exposes port `5678` (FastAPI) and `5679` (Celery worker).
3. Open VS Code, navigate to the Debug panel, select **"FastAPI: Remote Attach (Docker)"** or **"Celery Worker: Remote Attach (Docker)"**, and press **F5**.
4. Set breakpoints directly in your VS Code workspace.

---

## 9. Logging & Debugging Strategy

### Logging Levels & Targets
By default, services log to stdout/stderr. In local development:
* FastAPI: Configured with `uvicorn` default formatting. Log level is set to `DEBUG` (controlled via `LOG_LEVEL` env var).
* Celery: Logs task events to output console. Check Celery task logs via:
  ```powershell
  .\run.ps1 logs worker
  ```
* PostgreSQL/Nginx: Print connection details to standard streams, viewable via Docker Desktop dashboard.

---

## 10. Local Testing Strategy

Unit and integration tests are run inside containers to guarantee dependency parity.

### Running Tests
Use the PowerShell script `run.ps1`:
```powershell
# Run all tests (FastAPI, Celery, and Next.js)
.\run.ps1 test

# Run only backend api tests
.\run.ps1 test backend
```

---

## 11. Security & Backup Guidelines

### Local Secrets Management
* Never save passwords, API keys, or JWT secrets in code files.
* Use Python's `pydantic_settings` or `os.getenv` to pull values dynamically.
* Hardcoded secrets in Pull Requests will fail static analysis audits.

### Local Database Backup (PostgreSQL)
To snapshot your database schema and mock records for reference:
```powershell
docker exec -t svara-postgres pg_dumpall -c -U svara_user > svara_db_backup.sql
```

To restore the backup:
```powershell
cat svara_db_backup.sql | docker exec -i svara-postgres psql -U svara_user -d svara_db
```

---

## 12. Local Development Checklist

### First-Time Project Setup
- [ ] Install Docker Desktop and configure WSL2 integration.
- [ ] Initialize Python Virtual Environment locally:
  ```bash
  cd backend && python -m venv .venv
  ```
- [ ] Initialize VS Code: install recommended workspace plugins.
- [ ] Create `.env` from `.env.example` template.
- [ ] Boot the Docker system:
  ```powershell
  .\run.ps1 start
  ```
- [ ] Verify container states:
  ```powershell
  .\run.ps1 status
  ```
- [ ] Verify health check returns successfully:
  ```powershell
  curl.exe -s http://127.0.0.1/api/health
  ```
- [ ] Launch MinIO Console at `http://localhost:9001` and verify buckets `svara-audio` and `svara-voices` exist.

### Daily Workspace Workflow
1. Bring stack online: `.\run.ps1 start`
2. Create feature branch: `git checkout -b feature/my-cool-feature`
3. Launch VS Code debugging profile if tracing execution.
4. Auto-format before staging: `.\run.ps1 format`
5. Verify tests pass: `.\run.ps1 test`
6. Commit changes using Semantic format: `git commit -m "feat: add user api key deletion endpoint"`
7. Push and open PR on GitHub against `develop`.
