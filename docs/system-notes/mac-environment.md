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
  > ANSWER:
- **Q1.2** If not MAMP, what serves PHP on this machine? (macOS built-in Apache,
  Homebrew Apache/nginx, Valet, Docker, something else?) Give the config file
  paths (e.g. `httpd.conf`, vhosts file) and how it's started.
  > ANSWER:
- **Q1.3** List the virtual hosts / served directories and their document roots.
  Look in Apache config AND `/etc/hosts` for entries like
  `isrstamps.azuresults.com`, `judaica.azuresults.com`,
  `isrstamps.admin.azuresults.com`, or similar.
  > ANSWER:

## 2. Database

- **Q2.1** Which MySQL/MariaDB runs here (MAMP's bundled MySQL, Homebrew
  mysql/mariadb, other)? Version, socket/port, and how it's started.
  > ANSWER:
- **Q2.2** List the databases (run `SHOW DATABASES`). Which holds the
  historical mirror data and which holds current SIS data? **Note:** on PC the
  historical DB is `isr_original` and the current DB is `isrstamps`; we believe
  the Mac may name them differently.
  > ANSWER:
- **Q2.3** For the stamp databases, list the tables (`SHOW TABLES`) and, if
  easy, `mysqldump --no-data` schemas into
  `docs/system-notes/mac-db-schema.sql` so both sides can compare.
  > ANSWER:

## 3. The access-layer PHP code

- **Q3.1** Where do the PHP scripts that the iOS app / sites call actually
  live? (e.g. `/Applications/MAMP/htdocs/...`, `~/Sites/...`) Give the full
  path and a file listing.
  > ANSWER:
- **Q3.2** Is that code under git? If yes: repo path, remote URL, current
  branch, and `git log -5 --oneline`. If no: note it, and check whether a
  sibling folder or zip looks like a backup/version.
  > ANSWER:
- **Q3.3** Compare the newest files there to the Windows versions at
  `C:\MyWebsites\scripts\` (you can't see Windows — instead, record the
  modification dates and sizes of `dbconnect.php`, `dbconnectjs.php`,
  `incpath.php`, and any DB-name constants inside them, especially which
  database names they connect to).
  > ANSWER:
- **Q3.4** Any other PHP/app code on this machine that serves the stamp sites
  (search `/Applications/MAMP`, `~/Sites`, `/Library/WebServer/Documents`,
  `~/Projects`, `~/azuresults*` or similar)?
  > ANSWER:

## 4. This repo on the Mac

- **Q4.1** Where is the local `StampCollection` clone, what branch, and does
  it have unpushed commits or uncommitted changes (`git status`, `git log
  origin/main..HEAD --oneline`)?
  > ANSWER:
- **Q4.2** Which Xcode version builds it, and does the workspace use
  CocoaPods, SPM, or both? Do `pod install` / builds currently succeed?
  > ANSWER:
- **Q4.3** In the app source, which hostnames/URLs does it hit for data and
  images? (search for `azuresults`, `http://`, `https://`, `BTDealerStore`,
  picref/download URL code). List file + line.
  > ANSWER:

## 5. Anything else

- **Q5.1** Notes/docs on this machine describing the setup (readme files,
  `docs/`, Notes app exports, Desktop txt files)? List paths.
  > ANSWER:
- **Q5.2** Anything about this system that exists ONLY on the Mac and would be
  lost if the disk died — uncommitted code, DB dumps never exported, config
  files? List them so we can back them up or bring them under version control.
  > ANSWER:

---
*Completed by Mac Devin on <date>. Session notes:*
