# CLAUDE.md — WSFS IPAM

**Naming:** everything is **WSFS IPAM** / `wsfs`. Env prefix `WSFS_`, database + role
`wsfs_ipam`, package `wsfs-ipam-backend`, loggers `wsfs.*`, NSSM service name `WSFS-IPAM`.
(Originally codenamed "Subnetix"; fully renamed 2026-07-07 — no `subnetix` should remain
except the stale `backend/subnetix_backend.egg-info/`, regenerated on next `pip install`.)

Web-based **IP Address Management** for a datacenter. Two parts:
- **backend/** — Python 3.12/3.13, FastAPI (async) + PostgreSQL (SQLAlchemy 2.0 async, asyncpg, Alembic). REST API, live scan engine (SSE), NX-OS ARP collector.
- **frontend/** — React 18 + TypeScript + Vite 6, React Router 7, TanStack Query 5. Recreates the "Slate" design (light/dark).

Full docs live in `docs/`: **`codebase-manual.html`** (architecture/API reference), **`operations-manual.html`** (deploy/run), `BACKEND_DESIGN.md`, `WINDOWS_DEPLOY.md`. Read those for depth; this file is the working context.

## Status (all built & verified against the running stack)
Backend phases 1–5 complete: subnets/addresses CRUD, CSV import, search, scan history, audit; live SSE scan engine; NX-OS ARP collector + conflicts + OUI; structured logging; deploy artifacts. Frontend complete (all screens, both themes). Site + subnet + device management UI done. Windows Server 2022 native deploy path done. Two HTML manuals + top-level README done.
**Not done / open:** real auth (v1 is a stub admin — RBAC is v2), IPv6, SNMPv3, switch-port mapping, DHCP/DNS ingestion. The Docker files and Windows NSSM/service scripts are written but **never validated on real infra** (no Docker/NSSM on this box) — flagged in the manuals.

## Dev environment (Windows, non-obvious — read before running anything)
No system Node, Docker, uv, or psql on this box. Everything is portable/in-project:
- **PostgreSQL**: portable cluster in `.pgdev/` (gitignored), **port 5433**, trust auth, user `wsfs_ipam`, db `wsfs_ipam`. Manage: `backend\scripts\dev-db.ps1 start|stop|status`.
- **Node**: portable `.nodedev\node-v22.12.0-win-x64` (gitignored). Run via `.\frontend-dev.ps1 npm <args>` (puts it on PATH), or prepend that dir to `$env:Path`.
- **Backend venv**: `backend\.venv`. Python 3.13 system install exists but use the venv.
- Shell is **Windows PowerShell 5.1** (`powershell.exe`) — see gotchas.

## Run it
```powershell
# DB
cd backend ; .\scripts\dev-db.ps1 start
.\.venv\Scripts\alembic upgrade head
.\.venv\Scripts\python scripts\seed.py            # DESTRUCTIVE: TRUNCATEs then seeds demo data
.\.venv\Scripts\uvicorn app.main:app              # API on :8000  (add WSFS_STATIC_DIR to also serve the SPA)
.\.venv\Scripts\pytest                             # 23 tests
# Frontend (from repo root)
.\frontend-dev.ps1 npm run dev                     # SPA on :5173, proxies /api -> 127.0.0.1:8000
.\frontend-dev.ps1 npx tsc --noEmit                # typecheck
.\frontend-dev.ps1 npm run build                   # -> frontend/dist
```
Config = `WSFS_`-prefixed env vars (see `backend/app/config.py`, `backend/.env.example`). Dev default DB URL already points at 5433.

## Conventions & gotchas (load-bearing — these caused real bugs)
- **Sparse address storage**: only `active`/`reserved` IPs have rows; **free = no row**. The frontend synthesizes free cells from the CIDR (`frontend/src/lib/ipmath.ts`). Counts derive free = usable − stored.
- **Async rollback trap**: awaiting `session.rollback()` right after a flush `IntegrityError` raises `MissingGreenlet` under uvicorn/Windows. Pattern: **pre-check conflicts with a SELECT before inserting** (return clean 409); rollback is centralized in `get_db`. Same lesson in the scan cancel path (uses a fresh session).
- **Vite proxy targets `127.0.0.1:8000`, not `localhost`** — Windows resolves localhost to IPv6 where uvicorn isn't listening.
- **Alembic logs to stdout** (alembic.ini) so PowerShell doesn't misread a successful migration as failure.
- **PowerShell 5.1 deploy scripts** (`backend/deploy/windows/*.ps1`): must be **ASCII-only** (Write tool saves UTF-8 no-BOM; 5.1 mis-decodes em-dashes and breaks strings), no `?.`/`??`, and native-command stderr under `ErrorActionPreference=Stop` is treated as failure (drop to Continue + gate on `$LASTEXITCODE`).
- **Simulated backends are the dev default**: `WSFS_PROBER=simulated`, `WSFS_ARP_COLLECTOR=simulated` (fabricate from stored data, no network/privileges). Real: `real`/`nxapi`/`ssh` need the `probe`/`collect` pip extras + config. ICMP raw sockets need Admin on Windows; ARP collector (NX-API, HTTPS) does not — prefer ARP.
- Every mutation calls `write_audit()`; API errors are RFC 7807 `application/problem+json` with `detail`.
- Frontend styling = inline styles referencing CSS-variable tokens (`index.css`), plus a few `.hoverable/.card-hover/.cell` classes for `:hover`.

## Verifying changes (no visible browser here)
- Backend: `pytest`, and hit `http://localhost:8000/api/v1/...` (curl/Invoke-RestMethod).
- Frontend UI: headless Edge at `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` — `--headless=new --dump-dom <url>` or `--screenshot=<png> --virtual-time-budget=6000 --window-size=1440,900`. **Kill lingering `msedge` first and use a UNIQUE `--user-data-dir` per call** or runs collide on the profile lock and return empty.
- SSE scan stream: verified via a Node `fetch` reading `/scans/{id}/events` through the proxy.

## IMPORTANT: the user runs the app live — do NOT reseed blindly
The user actively uses the running app and has created real data through the UI (e.g. a "LAB / Wayne, PA" site). `scripts\seed.py` TRUNCATEs — running it wipes their data. Don't reseed unless asked; if a test mutated data, prefer targeted cleanup.

## Currently running: backend :8000, frontend :5173, postgres :5433.

## Key files
- Backend: `app/main.py` (app+SPA mount+lifespan), `app/config.py`, `app/services/scan_manager.py`, `app/services/arp_collect.py`, `app/services/probes/`, `app/services/collectors/`, `app/api/*`, `alembic/versions/edac43facecf_initial_schema.py` (btree_gist + GiST overlap constraint added by hand).
- Frontend: `src/lib/{api,types,hooks,useScan,ipmath,format}.ts`, `src/pages/{Dashboard,SubnetDetail,Devices,ScanHistory,AuditLog}.tsx`, `src/components/*`.
