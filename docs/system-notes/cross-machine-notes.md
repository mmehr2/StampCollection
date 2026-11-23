# Cross-Machine Notes — TRANSITION INSTRUCTIONS (read this file, Mac-Devin)

This file's contents have moved to the new shared coordination repo
**github.com/mmehr2/azuresults-stamp-system**. When the owner asks you to
"do the instructions in here," do exactly this:

## Instructions for Mac-Devin

1. **Read the shared repo** (don't clone yet, just read — or clone and read):
   `https://github.com/mmehr2/azuresults-stamp-system`
   Key files: `README.md` (working rules + the Win/Mac responsibility
   split), `repo-map.md`, `high-level-design.md`, `anomaly-list.md`.

2. **Clone the shared repo on this Mac** to a sensible spot alongside your
   other projects, e.g.:
   ```
   git clone https://github.com/mmehr2/azuresults-stamp-system.git \
     ~/Documents/Projects/azuresults-stamp-system
   ```
   You are read-write there — it's jointly owned, unlike this repo.

3. **OpenSpec is already initialized in it** (committed `openspec/`). Skills
   are machine-global, so if OpenSpec CLI isn't installed on this Mac yet:
   `curl -fsSL https://openspec.dev/cli/install.sh | sh` then
   `openspec init --tools devin` inside the new clone is optional — the
   `openspec/` structure already exists.

4. **Update `repo-map.md`** in the new repo: fill in the Mac clone path for
   `azuresults-stamp-system` (currently marked `TBD`), and fix anything else
   that's drifted. Commit and push.

5. **Do NOT pull the old content back into this file.** This file is your
   last write in `StampCollection/docs/system-notes/` — after completing
   steps 1–4, replace this file's contents with a short pointer (see below).

6. **Check off / pick up your tasks** from `anomaly-list.md` — e.g.
   `dbconnect3.php` deletion, mirror-content backup, and the
   INFO.csv/INVENTORY.csv data-model note that should be lifted into
   `StampCollection/openspec/` (per high-level-design.md, Win-Devin
   additions #3).

7. **Write the pointer version of this file** (step 5's replacement):

   ```markdown
   # Cross-Machine Notes — MOVED
   Coordination lives in github.com/mmehr2/azuresults-stamp-system
   (local clone: <your path here>). See README.md there for rules.
   ```

## Context summary (so you know why)

- Two-Devin setup: **Win-Devin** owns PC repos (SIS, MyWebSites);
  **Mac-Devin** owns Mac repos (StampCollection, azuresults-mac-webserver);
  the new shared repo is jointly writable — that includes protocol specs.
- Everything previously in this file was migrated and split into topical
  files on 2026-11-22. History here is preserved in git.
- Working rule going forward: every non-trivial change goes through
  OpenSpec; coordination docs note author + date and get pushed promptly.

*— Win-Devin, 2026-11-22*
