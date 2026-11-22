# Mac Environment Questionnaire

> **For the Devin instance on the Mac:** please investigate this machine and
> fill in each `> ANSWER:` block below, then commit and push. The Windows-side
> Devin session will pull your answers to build an accurate cross-machine map
> of the stamp-collection system. Be concrete: file paths, DB names, versions,
> and `git` status where applicable. If a question doesn't apply, write `n/a`
> with a one-line reason.
>
> Context you need: the system has three parts — SIS (Laravel admin/data
> entry, current data since mid-2018), a historical website mirror (frozen
> mid-2018), and this iOS app. On Windows there are TWO MySQL databases:
> `isrstamps` (current, used by SIS) and `isr_original` (historical mirror).
> A shared PHP access layer in `C:\MyWebsites\scripts\` was supposed to serve
> both to web + iOS, but never worked for the iOS app, so server code was
> moved to this Mac — possibly under MAMP, possibly elsewhere. We're trying to
> find out what actually exists here.

## 1. Web server stack

- **Q1.1** Is MAMP installed (`/Applications/MAMP`)? If yes, what version, and
  is it MAMP or MAMP Pro?
  > ANSWER: No — `/Applications/MAMP` does not exist; no MAMP or MAMP Pro on
  > this machine.
- **Q1.2** If not MAMP, what serves PHP on this machine? (macOS built-in Apache,
  Homebrew Apache/nginx, Valet, Docker, something else?) Give the config file
  paths (e.g. `httpd.conf`, vhosts file) and how it's started.
  > ANSWER: **Homebrew Apache httpd 2.4** (`/opt/homebrew/opt/httpd/bin/httpd`)
  > is the live server — it owns port 80 (`*.80 LISTEN`). It runs as root,
  > started at boot by launchd via `/Library/LaunchDaemons/homebrew.mxcl.httpd.plist`
  > (installed Apr 2026; NOTE: `brew services list` in the user domain shows it
  > as stopped — it is managed by the *root* launchd plist, not the user's).
  > PHP is **mod_php**: `httpd.conf` line 131 loads
  > `/opt/homebrew/opt/php/lib/httpd/modules/libphp.so` (PHP 8.5.5, Homebrew).
  > Config: `/opt/homebrew/etc/httpd/httpd.conf` (Listen 80,
  > DocumentRoot `/Library/WebServer/Documents`) +
  > `/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf`.
  > A **Homebrew php-fpm 8.5** also runs (user LaunchAgent
  > `~/Library/LaunchAgents/homebrew.mxcl.php.plist`, listening on
  > 127.0.0.1:9000, conf `/opt/homebrew/etc/php/8.5/php-fpm.conf`) but Apache
  > does NOT proxy to it — it's unused by the site setup.
  > Apple's own Apache (`/etc/apache2/httpd.conf`, edited to load the same
  > Homebrew libphp.so and Listen 80+8080, vhosts in
  > `/etc/apache2/extra/httpd-vhosts.conf`) is configured similarly but is NOT
  > running — `/usr/sbin/httpd` has no processes.
- **Q1.3** List the virtual hosts / served directories and their document roots.
  Look in Apache config AND `/etc/hosts` for entries like
  `isrstamps.azuresults.com`, `judaica.azuresults.com`,
  `isrstamps.admin.azuresults.com`, or similar.
  > ANSWER: `/etc/hosts` maps all stamp hosts to **192.168.1.80 — this Mac's
  > own en0 address**:
  > `192.168.1.80  isrstamps.azuresults.com judaica.azuresults.com isrstamps.admin.azuresults.com`
  > (plus unrelated `192.168.10.10/.11 homestead.app/homestead2.app` leftovers).
  > Active vhosts in `/opt/homebrew/etc/httpd/extra/httpd-vhosts.conf` (all `*:80`,
  > all with `ServerAlias 192.168.1.80`, CORS `Access-Control-Allow-Origin: *`):
  > - `localhost` → `/Library/WebServer/Documents` (LAN/local only)
  > - `isrstamps.azuresults.com` → `/Library/WebServer/Documents/BaitTov/bait-tov.com`
  >   (also grants access to `/Library/WebServer/Documents/scripts/`)
  > - `isrstamps.admin.azuresults.com` → `/Library/WebServer/Documents/IsrStamps/isrstamps.admin.azuresults.com`
  >   (also grants `scripts/`)
  > - `judaica.azuresults.com` → `/Library/WebServer/Documents/JudaicaSales/judaicasales.com`,
  >   `Alias /pics` → `.../judaicasales.com/pics`, `.asp`→`.php` rewrite, plus `scripts/`
  > The identical vhost set exists in `/etc/apache2/extra/httpd-vhosts.conf`
  > (the dormant Apple config). Verified live: `curl http://localhost/` returns
  > a phpinfo-style page; curl with `Host: isrstamps.azuresults.com` reaches Apache.

## 2. Database

- **Q2.1** Which MySQL/MariaDB runs here (MAMP's bundled MySQL, Homebrew
  mysql/mariadb, other)? Version, socket/port, and how it's started.
  > ANSWER: **Oracle MySQL Community Server 8.0.17** (x86_64 build, installed at
  > `/usr/local/mysql`, datadir `/usr/local/mysql/data`). Running since
  > 13 Sep 2026 as `_mysql`, started by launchd:
  > `/Library/LaunchDaemons/com.oracle.oss.mysql.mysqld.plist` (and a 2015-era
  > `com.mysql.mysql.plist`). Port **3306** (+ X Protocol **33060**), socket
  > `/tmp/mysql.sock`. Uses `mysql_native_password`. Credentials in the PHP
  > layer: `root` / `00mlmMLM` @ `127.0.0.1` (see `scripts/dbvars.php`).
  > No MariaDB, no Homebrew MySQL.
- **Q2.2** List the databases (run `SHOW DATABASES`). Which holds the
  historical mirror data and which holds current SIS data? **Note:** on PC the
  historical DB is `isr_original` and the current DB is `isrstamps`; we believe
  the Mac may name them differently.
  > ANSWER: `SHOW DATABASES` → `information_schema`, `isrstamps`, `mysql`,
  > `performance_schema`, `phpmyadmin`, `sys`.
  > **Only ONE stamp DB exists here: `isrstamps`** — and it holds the
  > *historical mirror* data (urlmap tables imported from the HTTrack mirror's
  > `new.txt`). There is **no `isr_original` and no SIS/current-data database
  > on this Mac.** The Mac's `isrstamps` plays the role the PC calls
  > `isr_original` — confirmed by the comment in `dbconnect.php`:
  > `// UPDATE: now "isr_original" on PC, "isrstamps" on Mac (non-admin) still`.
  > `phpmyadmin` is the PMA control database.
- **Q2.3** For the stamp databases, list the tables (`SHOW TABLES`) and, if
  easy, `mysqldump --no-data` schemas into
  `docs/system-notes/mac-db-schema.sql` so both sides can compare.
  > ANSWER: `isrstamps` has 3 tables, all **MyISAM**:
  > `urlmap` (~58,104 rows), `urlmap.js` (~599), `urlmap.new` (~1,261).
  > Each maps mirror URLs → local files (`URL`, `localfile`, `fromURL`,
  > `statusCode`, `MIME`, …). Schema-only dump written to
  > `docs/system-notes/mac-db-schema.sql` (committed alongside this file).

## 3. The access-layer PHP code

- **Q3.1** Where do the PHP scripts that the iOS app / sites call actually
  live? (e.g. `/Applications/MAMP/htdocs/...`, `~/Sites/...`) Give the full
  path and a file listing.
  > ANSWER: **`/Library/WebServer/Documents/scripts/`** — the Mac equivalent of
  > `C:\MyWebsites\scripts\`. Contents: `catrefs.php`, `cors.php`,
  > `dbconnect.php`, `dbconnect3.php`, `dbconnectjs.php`, `dbg_log.php`,
  > `dbsetup.sql`, `dbvars.php`, `exectype.php`, `leaflets.sql`,
  > `picref_input.php`, `readme.system.txt`, `readme.webdesign.txt` (695 KB!),
  > `utils.php`, `utilsjs.php`; subdirs `conf-mac/` (empty), `conf-pc/` (old PC
  > httpd confs + readmes), `misc/` (empty), `sitedata/` (`db_sis.sql`,
  > `dbsetup.sql`), `store/` (empty), `update_data/` (mirror import data incl.
  > `new.txt` 404 KB, `new0.txt` 15 MB, `scrape.sql`). Each site's docroot has
  > a 3-line `incpath.php` that appends `scripts/` to the PHP include path.
  > Additional endpoint PHP sits in the docroot itself: `store/pic.php`,
  > `store/products.php`, `store/viewcat.php`, `judaica/austrian.php`,
  > `judaica/austrian_pic_detail.php`, and top-level `index.php` (phpinfo page).
- **Q3.2** Is that code under git? If yes: repo path, remote URL, current
  branch, and `git log -5 --oneline`. If no: note it, and check whether a
  sibling folder or zip looks like a backup/version.
  > ANSWER: Yes — the ENTIRE docroot is one repo:
  > `/Library/WebServer/Documents/.git`, branch `master`, **NO remote**
  > (local-only, never pushed anywhere). Log:
  > `ea1cc6c Saving scripts before changes to add second urlmap from additional 2018+ site.`
  > `5d75e30 New version to ignore site data for now.`
  > `b03909f Initial commit.`
  > **~20 files modified but uncommitted** (all of scripts/, `.gitignore`,
  > update_data) plus untracked `index.php` — last commit predates the current
  > file dates, so the live code is uncommitted work. No zips/backups found.
- **Q3.3** Compare the newest files there to the Windows versions at
  `C:\MyWebsites\scripts\` (you can't see Windows — instead, record the
  modification dates and sizes of `dbconnect.php`, `dbconnectjs.php`,
  `incpath.php`, and any DB-name constants inside them, especially which
  database names they connect to).
  > ANSWER: `dbconnect.php` 8,404 B — 3 Sep 2021; `dbconnectjs.php` 7,556 B —
  > 4 Sep 2021; `dbconnect3.php` 8,412 B — 2 Sep 2021; `dbvars.php` 204 B —
  > 1 Oct 2019; `utils.php` 16,403 B — 20 Apr 2026; `exectype.php` 596 B —
  > 12 Apr 2026; `utilsjs.php` 4,431 B — 12 Apr 2026. No `incpath.php` in
  > `scripts/` — it lives per-site (`BaitTov/bait-tov.com/incpath.php`,
  > `JudaicaSales/judaicasales.com/incpath.php`, 162 B each, 2019).
  > DB constants: all connectors target DB **`isrstamps`** as `root`.
  > `dbconnect.php` uses host `127.0.0.1`, password `00mlmMLM` (matches live
  > MySQL 8). **Stale leftovers:** `dbconnect3.php` and the `dbquery()` in
  > `dbconnectjs.php` still use `localhost` + `w3lcome2MARIA!!!` (old MariaDB
  > credential) — those code paths would fail against the current MySQL;
  > `dbconnectjs.php:dblookup()` does use `00mlmMLM`. `dbvars.php` also uses
  > `00mlmMLM`/`isrstamps`.
- **Q3.4** Any other PHP/app code on this machine that serves the stamp sites
  (search `/Applications/MAMP`, `~/Sites`, `/Library/WebServer/Documents`,
  `~/Projects`, `~/azuresults*` or similar)?
  > ANSWER: The site code itself is in the docroot:
  > `BaitTov/bait-tov.com/` (`store/` with ~18,500 files: product pages, pics,
  > `atlas/`, `images/`, `photos/`), `JudaicaSales/judaicasales.com/`
  > (`judaica/` listings, `pics/`, `images/`), and
  > `IsrStamps/isrstamps.admin.azuresults.com/` — an **HTTrack mirror**
  > (`hts-log.txt`, `cookies.txt`, ~Jul 2020). `~/Sites` contains only
  > `info.php`, `phpinfo.php`, and an old **phpMyAdmin 4.4.14.1** (not reachable
  > — `~mikemehr` userdir isn't configured in the running Apache; `Desktop/
  > config.inc.php` is likely its config). No `~/Projects`, no `~/azuresults*`.
  > `~/Desktop/IsraelStamps/` is a folder of stamp product JPGs (`6110*.jpg`).

## 4. This repo on the Mac

- **Q4.1** Where is the local `StampCollection` clone, what branch, and does
  it have unpushed commits or uncommitted changes (`git status`, `git log
  origin/main..HEAD --oneline`)?
  > ANSWER: `/Users/mikemehr/Documents/Projects/StampCollection`, branch
  > `master`, remote **`stamps`** → `https://github.com/mmehr2/StampCollection`.
  > No unpushed commits (`stamps/master..HEAD` empty, up to date at `41ae5e0`).
  > Only change: new untracked `docs/system-notes/mac-db-schema.sql` + this
  > answered questionnaire — both committed with this session.
- **Q4.2** Which Xcode version builds it, and does the workspace use
  CocoaPods, SPM, or both? Do `pod install` / builds currently succeed?
  > ANSWER: **Xcode 16.2** (16C5032a) at `/Applications/Xcode.app`; CocoaPods
  > 1.16.2 installed. Dependency setup: **SPM is the live mechanism** —
  > `SwiftSoup` via `XCRemoteSwiftPackageReference` (upToNextMajorVersion) in
  > `project.pbxproj`. The `Podfile` still exists but every pod is commented
  > out ("Using SwiftSoup via Swift Package Manager now"); `Pods/` and
  > `Podfile.lock` (generated by CP 1.12.0) are stale leftovers — `pod install`
  > is a no-op. **Builds currently FAIL**: Debug simulator build
  > (`CODE_SIGNING_ALLOWED=NO`) fails with
  > `BTItemsMessageProcessor.swift:51: compiling for iOS 12.0, but module
  > 'SwiftSoup' has a minimum deployment target of iOS 13.0`. Fix = raise
  > `IPHONEOS_DEPLOYMENT_TARGET` to ≥13.0.
- **Q4.3** In the app source, which hostnames/URLs does it hit for data and
  images? (search for `azuresults`, `http://`, `https://`, `BTDealerStore`,
  picref/download URL code). List file + line.
  > ANSWER: Both delegates have `useLocalSite = true`, so the app currently
  > hits the **in-house (this Mac's) sites**:
  > - `BTMessageDelegate.swift:51-53` — `BTBaseURL0 http://www.bait-tov.com/store/`
  >   (public) vs `BTBaseURL1 http://192.168.1.82/store/` (local, selected).
  >   **NOTE: hardcodes `192.168.1.82`, but this Mac is `.80`** — probably a
  >   stale PC address; the commented equivalent is
  >   `http://isrstamps.azuresults.com/store/`.
  > - `BTMessageDelegate.swift:164` — sets `Host: isrstamps.azuresults.com`
  >   header on local requests (name-based vhost routing).
  > - `JSMessageDelegate.swift:23-25` — `JSBaseURL0 http://www.judaicasales.com`
  >   vs `JSBaseURL1 http://192.168.1.80/JudaicaSales/judaicasales.com`
  >   (selected; commented equiv `judaica.azuresults.com`).
  > - `ItemPicURL.swift:215-222` — image URLs: BT `…/store/products/<pictid>.jpg`,
  >   JS `…/pics/judaica_austriantabs/ajt<picref>.jpg`; `BTDealerStore.swift:16-17`
  >   documents `store/products/…jpg` + `store/pic.php?ID=…`.
  > - `Info.plist:91-133` — ATS exceptions allow HTTP to `192.168.1.80`,
  >   `192.168.1.82`, `192.168.1.80.nip.io`, `judaica.azuresults.com`,
  >   `isrstamps.azuresults.com`, `bait-tov.com`, `judaicasales.com`.
  > Data pages: `store/products.php?SubCat=…`, `store/pic.php?ID=…`,
  > `store/proddet.php` (`BTItemsMessageProcessor.swift:38`, `:288`).

## 5. Anything else

- **Q5.1** Notes/docs on this machine describing the setup (readme files,
  `docs/`, Notes app exports, Desktop txt files)? List paths.
  > ANSWER:
  > - `/Library/WebServer/Documents/scripts/readme.system.txt` (10 KB, Sep 2019)
  >   and `readme.webdesign.txt` (695 KB, Sep 2021) — primary system docs
  > - `scripts/conf-pc/` — old PC `httpd.conf`/vhosts + `readme.system.old.txt`,
  >   `readme.webdesign.old.txt`
  > - `~/Desktop/StampWebsiteNotes.rtf`, `~/Desktop/System Notes.rtf`,
  >   `~/Desktop/Git Notes.rtf`, `~/Desktop/StampCollectionErrorLog.2015.07.16.rtf`,
  >   `~/Desktop/config.inc.php` (phpMyAdmin config)
  > - `~/Documents/DebugSim6FullLoadMirrorSite.rtf`
  > - This repo: `docs/system-notes/` (this file), `openspec/project.md`
- **Q5.2** Anything about this system that exists ONLY on the Mac and would be
  lost if the disk died — uncommitted code, DB dumps never exported, config
  files? List them so we can back them up or bring them under version control.
  > ANSWER: Significant — most of the server side lives only here:
  > 1. **`/Library/WebServer/Documents/` git repo has NO remote** — the only
  >    copy of `scripts/`, `BaitTov/`, `JudaicaSales/`, `IsrStamps/` site code,
  >    PLUS ~20 uncommitted modified files (all work since ~Sep 2021). Disk
  >    failure = total loss of the PHP access layer.
  > 2. **MySQL `isrstamps` data never exported** — urlmap tables (~59k rows)
  >    exist only in `/usr/local/mysql/data` (schema now dumped, but NOT data).
  > 3. **Server configs unversioned**: `/opt/homebrew/etc/httpd/*`,
  >    `/etc/apache2/*`, `/etc/hosts` entries, `/opt/homebrew/etc/php/8.5/*`,
  >    launchd plists.
  > 4. phpMyAdmin 4.4.14.1 + its `config.inc.php` (`~/Sites/phpmyadmin`,
  >    `~/Desktop/config.inc.php`).
  > 5. `~/Desktop/IsraelStamps/*.jpg` image collection; Desktop/Docs `.rtf`
  >    notes listed in Q5.1.
  > 6. The HTTrack mirror content itself (`IsrStamps/…`, `BaitTov/…/store/`
  >    ~18k files) — theoretically re-crawlable, but the only existing copy.

---
*Completed by Mac Devin on 2026-11-21. Session notes: no MAMP — Homebrew
httpd (mod_php 8.5) + Oracle MySQL 8.0.17 serve the mirror sites on LAN IP
192.168.1.80; single `isrstamps` DB = mirror urlmap only (no SIS data on Mac);
docroot is a remote-less git repo with uncommitted changes — biggest backup
risk. iOS app points at local sites (`useLocalSite=true`) but BT base URL
still hardcodes stale `192.168.1.82`. Build broken on iOS 12 vs SwiftSoup's
iOS 13 minimum.*
