# Cross-Machine Notes — Stamp Collection System

Running coordination notes between the two Devin instances. Both machines
pull this repo, so this file is the shared channel; keep it current as the
plan evolves. (For user-facing tracking, mirror items into GitHub issues.)

## Repo ownership map (2026-11-21)

| Repo | Remote | Responsible instance | Status |
|---|---|---|---|
| `StampCollection` (iOS app) | github.com/mmehr2/StampCollection | Mac-Devin | on `main`, synced |
| `azuresults-mac-webserver` (`/Library/WebServer/Documents`) | github.com/mmehr2/azuresults-mac-webserver | Mac-Devin | on `main`, synced, private |
| SIS data-entry app (Laravel 7) | not yet on GitHub | Win-Devin | local to Windows |
| Windows webserver copy (`C:\MyWebsites`) | not yet on GitHub | Win-Devin | local to Windows |

Long term: both machines should be aware of all repos. When SIS and the
Windows webserver come online, add them to this table.

## Planned work / future notes

- [ ] **Post-2018 data → webserver**: get new SIS data-entry rows (since the
      mid-2018 mirror freeze) into the webserver layer, *including all pic
      files*. Method TBD — likely file copies/exports, NOT git.
- [ ] **Machine-to-machine data sharing**: share data additions between Mac
      and Windows (direction/mechanism TBD). Keep bulk stamp data out of the
      GitHub repos — the repos carry code + docs, not datasets.
- [ ] Mac side currently holds only the mirror `isrstamps` DB (urlmap
      tables); SIS's current DB lives on Windows (`isrstamps` there /
      `isr_original` historical). Any cross-pollination must reconcile the
      same-name-different-role databases. See `mac-environment.md` Q2.2.

## Operational notes for Win-Devin

- `StampCollection` default branch renamed `master` → `main` on 2026-11-21.
  Windows clone recovery (do NOT just `git pull`):
  ```
  git fetch stamps --prune
  git branch -m master main
  git branch -u stamps/main main
  git remote set-head stamps -a
  ```
- The Mac webserver repo default branch is `main`.
- Credential refactor 2026-11-21: all `dbconnect*.php` now read
  `scripts/dbvars.php` — single source for host/user/pass/dbname.
