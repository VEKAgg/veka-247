# AGENTS.md — veka-247 (Multi-Channel Playout & Stream Engine)

> Python FastAPI, Svelte, 4x ffplayout, Restreamer, MediaMTX, Docker Compose.

---

## Session Protocol (read first — every session)

1. **Read** this AGENTS.md fully before touching any code.
2. **Do** the current task.
3. **Update** this AGENTS.md (Issue Tracker, decisions, gotchas) whenever context changes.
4. **Verify** quality gates → **commit + push** — one clean commit per task.
5. **Log** one line to the Bedrock vault journal: `C:\Users\Shafaat\Documents\Bedrock\60 Journal\<YYYY-MM-DD>.md` (create the file if missing).

---

## Agent Workflow (MANDATORY)

Every coding session must follow this loop for each task:

1. **Write the code** for the current task / step.
2. **Audit** — run quality gates. Fix any errors or warnings.
3. **Commit** — stage changes and commit with a descriptive message.
4. **Push** — push the commit.
5. **Move on** — only start the next task after the current one is linted, tested, committed, and pushed.

**Never batch multiple tasks into one commit. Each completed task = one clean commit.**

---

## Quality Gates (run before every push)

```bash
docker compose -f docker/docker-compose.yml config  # validate compose syntax
ruff check server/ scripts/ --fix                   # python backend lint
ruff format server/ scripts/                        # python formatting
pnpm --prefix dashboard check                       # svelte dashboard typecheck
```

| Gate | Command | Must pass |
|------|---------|-----------|
| Compose Config | `docker compose -f docker/docker-compose.yml config` | Yes |
| Backend Lint | `ruff check server/ scripts/` | Yes |
| Backend Format | `ruff format server/ scripts/` | Yes |
| Frontend Typecheck | `pnpm --prefix dashboard check` | Yes |

---

## Issue Tracker

Track all known issues, bugs, and technical debt here. Use consistent IDs.

### Format

| ID | Severity | Status | File | Description |
|----|----------|--------|------|-------------|
| FIX-001 | CRITICAL | ✅ Done | `server/main.py:42` | One-line problem description |
| FIX-002 | HIGH | ⬜ Open | `scripts/watchdog.sh:15` | One-line problem description |
| GAP-001 | MEDIUM | ⬜ Deferred | — | Missing feature or capability |

### Severity Levels

- **CRITICAL**: Stream offline, ffmpeg crash loops, media corruption, container crashes
- **HIGH**: Logic errors, broken clip schedules, Restreamer API failure
- **MEDIUM**: Code quality, dead code, missing error handling, performance
- **LOW**: Style, naming, documentation gaps

### Status Values

- `✅ Done` — Fixed in a previous session
- `⬜ Open` — Needs to be fixed
- `⬜ Deferred` — Known but deferred to a future session

### Open Issues & Architectural Gaps

| ID | Severity | Status | File | Description |
|----|----------|--------|------|-------------|
| GAP-001 | HIGH | ⬜ Open | `config/mediamtx.yml` | Configure live-stream ingest to allow SayaraOBS in-car stream to interrupt 24/7 loops |
| GAP-002 | HIGH | ⬜ Open | `server/services/` | Implement RuntimeState circuit breaker for ffplayout channel failure auto-recovery |
| GAP-003 | MEDIUM | ⬜ Open | `server/routers/` | Expose playout health & channel status API for veka.gg dashboard operations cockpit |
| GAP-004 | LOW | ⬜ Open | `scripts/` | Containerize clip normalization scripts and add automated integrity checks |

### Completed Fixes

| ID | Status | File |
|----|--------|------|
| — | — | Initial repository baseline established |

---

## Locked Design Decisions

Decisions confirmed by the owner. **Do not deviate without explicit instruction.**

| Decision | Chosen | Date |
|----------|--------|------|
| Channel architecture | 4 dedicated ffplayout instances: TTTR (8787), IGFV (8788), FH6 (8789), VA (8790) | 2026-01-15 |
| Ingest & Distribution | MediaMTX for low-latency ingest, Restreamer for multi-platform distribution | 2026-01-15 |
| Destination targets | Twitch Mumbai ingest, YouTube primary/backup, Kick RTMP | 2026-01-15 |
| Clip storage | Normalized MP4 clips in `/srv/clips/{channel}` at unified framerate and resolution | 2026-01-15 |

---

## Playout Channels & Ports

| Channel | Content | Clips Folder | ffplayout Port |
|---------|---------|-------------|----------------|
| TTTR | GTA5 Roleplay | `/srv/clips/tttr` | 8787 |
| IGFV | Elite Dangerous | `/srv/clips/igfv` | 8788 |
| FH6 | Forza Horizon 6 | `/srv/clips/fh6` | 8789 |
| VA | Rocket League | `/srv/clips/va` | 8790 |

---

## Pre-Submit Checklist

Before finishing any task, verify:

- [ ] `docker compose -f docker/docker-compose.yml config` — compose syntax valid
- [ ] `ruff check server/ scripts/` — clean
- [ ] `ruff format server/ scripts/` — formatted
- [ ] `pnpm --prefix dashboard check` — no type errors
- [ ] ffplayout channel ports unchanged (TTTR 8787, IGFV 8788, FH6 8789, VA 8790)
- [ ] AGENTS.md updated if context changed
