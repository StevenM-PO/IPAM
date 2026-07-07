# WSFS IPAM — Datacenter IP Address Management

Web-based **IP Address Management** for datacenter server endpoints: browse subnets and
utilization across sites, scan subnets to discover live endpoints, manage individual IPs,
collect MAC/vendor data from NX-OS switch ARP tables, detect duplicate-IP conflicts, and
audit every change.

- **Backend** — Python / FastAPI + PostgreSQL (async). REST API, live scan engine (SSE),
  NX-OS ARP collector.
- **Frontend** — React + TypeScript (Vite), recreating the "Slate" design (light/dark).

## Documentation

| Document | For |
|---|---|
| [**Codebase Manual**](docs/codebase-manual.html) | Developers — architecture, data model, scan/ARP engines, API, front-end |
| [**Operations & Installation Manual**](docs/operations-manual.html) | Administrators — install, configure, run, upgrade, troubleshoot |
| [Backend Design](docs/BACKEND_DESIGN.md) | The original design decisions and build phases |
| [Windows Deploy runbook](docs/WINDOWS_DEPLOY.md) | Step-by-step Windows Server 2022 deployment |
| [backend/README.md](backend/README.md) · [frontend/README.md](frontend/README.md) | Per-component dev setup |

> The two manuals are self-contained HTML — open them in any browser (they render light or
> dark to match your system).

## Quick start (local dev, Windows)

```powershell
# database (portable Postgres in .pgdev, port 5433)
cd backend ; .\scripts\dev-db.ps1 start
.\.venv\Scripts\alembic upgrade head ; .\.venv\Scripts\python scripts\seed.py
.\.venv\Scripts\uvicorn app.main:app          # API on :8000

# front-end (portable Node in .nodedev)
cd .. ; .\frontend-dev.ps1 npm run dev         # SPA on :5173 (proxies /api → :8000)
```

See the per-component READMEs for first-time setup, and the Operations Manual for
production deployment.

## Repository layout

```
backend/    FastAPI + PostgreSQL service (app/, alembic/, scripts/, deploy/, tests/)
frontend/   React + TypeScript + Vite SPA (src/)
docs/       manuals, design doc, deploy runbook
docker-compose.yml   Postgres + API (Linux)
```
