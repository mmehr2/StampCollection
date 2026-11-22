# Cross-Machine Notes — Stamp Collection System

Running coordination notes between the two Devin instances. Both machines
pull this repo, so this file is the shared channel; keep it current as the
plan evolves. (For user-facing tracking, mirror items into GitHub issues.)

## Repo ownership map (2026-11-21)

| Repo | Remote | Responsible instance | Status |
|---|---|---|---|
| `StampCollection` (iOS app) | github.com/mmehr2/StampCollection | Mac-Devin | on `main`, synced |
| `azuresults-mac-webserver` (`/Library/WebServer/Documents`) | github.com/mmehr2/azuresults-mac-webserver | Mac-Devin | on `main`, synced, private |
| SIS data-entry app (Laravel 7) | github.com/mmehr2/SIS | Win-Devin | on `master`, synced (rename pending) |
| Windows webserver copy (`C:\MyWebsites`) | github.com/mmehr2/MyWebSites | Win-Devin | on `master`, synced (rename pending) |

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

## Anomaly / cleanup list (compiled 2026-11-21)

### iOS app — Mac-Devin

- [ ] Fix build: raise `IPHONEOS_DEPLOYMENT_TARGET` to 13.0+ (SwiftSoup
      minimum); verify a simulator build succeeds.
- [ ] Stale IP: `BTMessageDelegate.swift` hardcodes `192.168.1.82`; Mac is
      `.80`. Prefer the name-based vhost (`isrstamps.azuresults.com`) that's
      already commented in the source — survives IP changes.
- [ ] Remove dead CocoaPods remnants (`Podfile`, `Podfile.lock`, `Pods/`):
      SPM is the live mechanism.

### Access layer / webserver — Mac-Devin

- [ ] Delete `scripts/dbconnect3.php` — stale pre-git copy of `dbconnect.php`
      kept for paranoia; git is the archive now. (dbconnect.php/dbconnectjs
      stale creds already fixed via `dbvars.php` refactor.)
- [ ] Mirror-content backup gap: ~18k files under the gitignored site dirs
      exist only on the Mac disk. Decide a non-git backup (NAS/cloud/export).
- [ ] (Optional) Convert `urlmap*` tables MyISAM → InnoDB.
- [ ] Accepted risk, no action: MySQL root password in `dbvars.php` is on
      GitHub history (private repo, LAN-only). If it ever matters, rotate the
      password rather than rewriting history.

### Windows-side — Win-Devin / decide together

- [ ] `IsrStamps/` folder (gitignored): owner recalls it may hold something
      useful — recheck against notes before deleting.
- [ ] Untracked strays in MyWebSites to triage: `composer.json`, `new.txt`,
      `image_rcv.php`/`image_send.php`, `update_data/*.csv`. NOTE per owner:
      `new.txt` is part of the HTTrack "fake static pages" mechanism for new
      data — keep for now; HTTrack is unreliable and a replacement mechanism
      is a future design task.
- [ ] Verify `.env.testing` points at a scratch DB before running PHPUnit
      (tests once wiped the real DB).

### Structural / future design — both

- [ ] Rename `master` → `main` on SIS and MyWebSites (recovery sequence above).
- [ ] Laravel 7 / PHP 7.2 upgrade — sequence of per-version OpenSpec changes.
- [ ] Design a replacement for the HTTrack fake-static-page mechanism.
- [ ] Unified access layer: historical + current DBs consumable by web + iOS
      (the big one — spec with OpenSpec when ready).

## Operational notes for Win-Devin

- `StampCollection` default branch renamed `master` → `main` on 2026-11-21.
  Recovery sequence (run per clone; do NOT just `git pull`):
  ```
  git fetch <remote> --prune        # <remote> = origin on Windows, stamps on Mac
  git branch -m master main
  git branch -u <remote>/main main
  git remote set-head <remote> -a
  ```
  Status: Windows clone recovered 2026-11-21. SIS and MyWebSites renames still
  pending — same sequence applies when done.
- The Mac webserver repo default branch is `main`.
- Credential refactor 2026-11-21: all `dbconnect*.php` now read
  `scripts/dbvars.php` — single source for host/user/pass/dbname.
