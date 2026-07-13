# ShivaAI Development Environment Specification
**Module 2**  

---

## 1. Local Development Workflow

The local development lifecycle runs through container orchestrations and auto-format loops:

```
[Write Code in VS Code] 
  |
  +---> [Format-On-Save] (Ruff for python / Prettier for JS)
  |
  +---> [Docker Hot-Reload] (Local code volume mounts immediately reload)
  |
  +---> [Run Verification] (.\run.ps1 test / .\run.ps1 lint)
```

To ensure a smooth developer experience on Windows systems, all tasks are encapsulated in a single PowerShell script CLI (`run.ps1`).

---

## 2. VS Code Workspace Configuration

The standard IDE environment is governed by workspace-level files committed to Git:

### A. Code Formatter Settings (`.vscode/settings.json`)
* Integrates format-on-save for Python, TypeScript, React, CSS, and Markdown.
* Maps `charliermarsh.ruff` as default python linter/formatter.
* Excludes virtual environment and Next.js caches from file searches and explorer views.

### B. Standard Extensions (`.vscode/extensions.json`)
* Python: `ms-python.python` & `charliermarsh.ruff`.
* Web Formatter: `esbenp.prettier-vscode` & `dbaeumer.vscode-eslint`.
* Containers: `ms-azuretools.vscode-docker` & `ms-vscode-remote.remote-wsl` (ensuring native Linux VM connectivity).

### C. Debugging Actions (`.vscode/launch.json`)
* Runs local debug configurations.
* Supports **remote attachment** via `debugpy` TCP ports `5678` (FastAPI) and `5679` (Celery worker).
* Maps client-side debug variables directly to local source mappings.

---

## 3. Environment Variables Strategy (.env)

* **`.env.example`** (Committed): Acts as the templates manifesto, mapping variables name keys, ports, and connection patterns without default secrets.
* **`.env`** (Ignored): The local configuration instance. Created by running:
  ```powershell
  Copy-Item .env.example .env
  ```
  This file must never be committed to Git.

---

## 4. Coding Standards & Lints Configurations

* **Python Linting**: Enforced via Ruff (`ruff.toml` in workspace root). Adheres to Black styles with a max line length of 88.
* **TS/JS Formatting**: Enforced via Prettier (`.prettierrc` in workspace root). Configures tabs, trailing commas, and semicolons.

---

## 5. Local Storage & Database Backup Policies

### Local Storage Structure
MinIO acts as S3 emulator in local compose. 
* Audio clips: Saved in persistent docker volume `minio_data` inside `/svara-audio`.
* Voice embeddings: Saved inside `/svara-voices`.

### Database Backup CLI
Developers can backup active schemas and mock states for reference:
```powershell
docker exec -t svara-postgres pg_dumpall -c -U svara_user > svara_db_backup.sql
```

To restore:
```powershell
cat svara_db_backup.sql | docker exec -i svara-postgres psql -U svara_user -d svara_db
```
