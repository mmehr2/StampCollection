# StampCollection — iOS app (Swift)

## What this is

Swift/UIKit iPhone app for browsing the stamp collection. Part of a
three-repo system — see `SIS/openspec/project.md` for the full map.

## Stack

- **Swift / UIKit** (storyboard-era; `StampCollection.xcodeproj` +
  `.xcworkspace`)
- **Swift Package Manager** — SwiftSoup is the only dependency (CocoaPods
  fully removed 2026-11-21; `Package.resolved` is committed)
- **Core Data** — entities include `AlbumCollection`, `AlbumFamily`,
  `AlbumPage`, `AlbumRef`, `AlbumSection`, plus stamp/issue/dealer models
- `StampCollectionTests/` — unit tests

## Development environment

- **Primary dev machine is a Mac (M2)** — Xcode required to build/run/test.
- This Windows clone is for cross-repo reasoning and OpenSpec planning;
  not buildable here. Keep in sync via git push/pull with the Mac copy.
- The app is also the reason the shared PHP access layer moved to MAMP on the
  Mac: the Windows-hosted `scripts/` layer never worked for the app.

## How it connects to the system

Per `C:\MyWebsites\scripts\readme.system.txt` and `dbconnect.php`:

- Image/picref URLs point at `isrstamps.azuresults.com` (historical mirror,
  `C:\MyWebsites\BaitTov\bait-tov.com`)
- A `BTDealerStore` download mechanism pulls store/catalog data
- A two-line mod let the iOS **simulator** use local vhosts instead of remote
  URLs; the dual-database access layer (historical `isr_original` vs current
  `isrstamps`) never fully worked for the app — major unresolved problem
- DB naming trap: the historical DB is called `isr_original` on PC but
  `isrstamps` on Mac

`WebItemViewController.swift` is the main web-facing component.

## Data model truth (owner-confirmed 2026-11-22)

- **`INFO.csv` is the catalog** — the "classes": ideal versions of items
  and their prices. Unchangeable reference data.
- **`INVENTORY.csv` is the owner's collection** — the "instances" of those
  catalog items actually held.
- These ship in the app bundle today via the `.sczp` → Xcode path; the
  long-term direction (see shared repo `high-level-design.md`) is for the
  app to fetch this data over HTTP like the site data, retiring `.sczp`.

## Notes

- `docs/` and loose files (`Stamp Diagram Y.txt`, `BTCATS.CSV`, `BTINFO.CSV`,
  `baitcfg.csv`) contain data formats and diagrams worth consulting before
  changing models.
