# StampCollection
My iOS code for managing my stamp collection.
Written in Swift 1.2 for iOS 8.0 but I intend to update it to the latest Swift version as much as possible.

Many comments in the code, but it's a complicated app, involving many features to manage a collection of 30-some categories (sub-collections) of philatelic items from Israel and related countries. It keeps track of a layer of dealer items with values (extended with other items of interest to me) and a second layer of actual inventory of my collection, either as want-list items or items physically in the collection. I also plan to add historical purchase and sale data eventually, but for now it will just show current valuations and album locations.

I have many plans, but the main features rely on CoreData for persistence, a networking layer currently powered by WebKit (but looking at AlamoFire to enhance), and a couple 3rd-party technologies:
  CHCSVParser - used to parse CSV files for backup/restore from the website version (legacy data)
  SSZipArchive - used to manage ZIP files to allow communicating those CSV files (3 needed) as a compressed group by email and perhaps later AirDrop or other technologies

I have tried to incorporate Swift and development best practices as best I understand them, but I only started learning the Apple Way in January 2015, after a career in MS Windows Development (C++, MFC, Visual Studio 2010) that spanned decades. So my understanding is a work in progress that I hope to keep up to date as Apple continues to change the Swift language, XCode, and iOS development in general. Perhaps I may also port this to the iPad and/or my Mac, but for now, I'm trying to make it portable on my iPhone so I can take it with me to conventions, etc.

-- Mike Mehr
June 8, 2015

## Design and Data
The following description was moved from the file InfoUtilities.swift to here, as it captures the design essence and a lot of information about the data and functionality the app plans to provide.
-- Mike Mehr
July 15, 2017


INFO is the Level 1 layer of collection data, representing the valuation and cataloging facilities of dealers.
INVENTORY is the Level 2 (L2) layer, representing which dealer items I have (or want) in my collection.
The original design had an implied Level 3 (L3) layer that would include info on inventory acquisition and disposition, but I never implemented that in the website project (2011-2013).
Currently I plan to add that function to L2 itself eventually in the Mac/IOS design here.

So this file will draw mostly on the contents of UTCommon.PHP, MOProcess.PHP, and maybe BTProcess or UICommon.PHP.
These files will be split across several utility files here, tho, and I don't currently have plans to allow for
the re-creation of the web data from scratch, so some features are eliminated. That, and with the direct data 
access ability from the live website ("scraping") provided by the NetworkModel module group here, I really 
don't need a lot of the functionality that was provided in the PHP system to deal with BAITTOVxx.TXT files 
that were really just copied and pasted from the website in a browser on Windows.

I may need to revisit the decision about re-creating from scratch. First I must decide about the need for extending the additional info (not carried by the website). Consider each in turn:

Folders and bulletins: (MOProcess)
---
The Morgenstin catalog was scanned in and tweaked into a CSV file (via OCR project). This only took us up to 2009.
So I added folder info for 2009-2013 in the PHP system and tweaked it by filling in from the website data.
Check again how this goes, but I think the PHP code provided basic description data, some assumptions about ID codes, and continuation of feXXX bulletin numbering (referring directly to the number on the bulletin itself).
This is a live issue (FE), but the BU catalog is complete (finished in 1988 or so) and should not change.
There is a newer Morgenstin catalog available in online form, but not clear how easy it would be to use that.
The 2009 catalog used Bale catalog numbers for reference, but prob.from Bale 2006. My extension data in PHP used Bale 2013 references (I think). In 2016 this will again be a problem, no doubt. :)
Moving forward, usage of the FE folder with new FDC shipment entry is well understood. Each FDC and FE item share a page in my FDC albums. Data entry must continue to allow updating of FE data alongside FDC data, some of which may not yet be available in the Sets base category either.


SIMA data: (MOProcess)
---
The website category for SIMA provides basic items (code 6110m) for a full set of mint labels and for the FDC of a single label, from IPS machine 001. This is in the same category with data from Klussendorf, Frama, MASSAD, and other vending labels (not DALIA). Only MASSAD is still being produced, so these items change the numbering.
So as I wish to collect extra varieties (blanco, other machine sets, FDC of all machine labels on one cover), I need to add a few things to the cataloging system.
In my correspondence with Tari Chelouche, he had developed a private catalog of all things SIMA as an XLS file. So I input that catalog v2.0 as a CSV file, and tried to keep that up to date.
I created a never version of it, in which I kept adding as much as I knew about new issues, and whether or not I had them. I also added support for blanco labels (now a hot area of collection effort 5/2015).
Moving forward, I would like to have the ability to import this data from the CSV as I change it. Alternatively, I could have a way of entering the needed L1 data from the presence of website data, but I would need to implement a screen for determining which machines were involved, and what rate sets were in use (these change throughout the year). Plus, the SIMA machines are being replaced this year, and this may have major consequences. At first, Yuval Assif at IPS said they wouldn't ship these, but then they arrived in my April shipment. The machines are dying and need to be replaced, since the manufacturer has obsoleted the design. So only time will tell how the changes will affect me.


IRCs (International Reply Coupons)
---
The website only sells 20 of these. Bale lists ~150. I've tried to gather a collection, so there was a need to add more info.
Currently there is only one standardized coupon in use, and its design changes seldom (once or twice a decade). This is done by the UPU and not by the IPC.
The PHP code was designed to fill in the blanks by supplementing the BT data enough to make the Bale equivalent. This had to account for anomalies in the Bale numbering scheme as well as the fact that I didn't want to re-enter all the Bale data. So I only used generic prices and descriptions that would need fixups later. Only I never got around to writing the fixup code. Editing could be performed one item at a time.
Moving forward, this is mostly about editing the 100 or so fixups in some easier fashion. A batch editing screen would be useful here. The ongoing changes could be dealt with by a single-item editor. Pricing data would mostly have to come from Bale (3 year updates) when BT was not available (only 20, a lot less than were on the site when I scanned it back in 2013). Of course, if BT started selling more of these, the needs could change.


Full Sheet data
---
This is a major project. I doubt BT will ever sell these, and no comprehensive dealer has emerged. But I have amassed a nearly complete collection back to the early days, so this is worth indexing properly.
BT provides the PHP code with the basic set data, including catalog descriptions in many cases (see FE data). The Sets category uses Scott and Carmel catalog data. I parsed these fields in the PHP code to tell how many denominations were in each set, and provided an entry in L1 (coded 6110t) for each individual denom in the set. I made some extensions to the description fields generated, and created these generically. However, I wanted more in the inventory, so I added screens to easily update the basic entries with more info regarding plate numbers and dates, as well as layout formats (rows, cols). I had only completed fixup of maybe the first few years, so this work is ongoing.
Moving forward, each new shipment from IPC contains all relevant sheets as well. Any irregular (non 5x3 format) sheets will also have FDCs generated (and some 5x3 as well) that I may be interested in. BT will sell these special sheets in a separate category (the only sheets they sell), with mint and FDC versions in most cases.
So I need to deal with the facts of BT selling some sheets (code 6110e) and the rest needing regular entries in my 6110t category.

Bul Sheli Extensions (My Own Stamp sheets)
--
Plus there is the issue of My Own Stamp sheets, of which BT sells some (generic and preprinted by IPC), but not the full set of what I collect (date varieties). I never really dealt with that in the PHP code so far. There are more dates needed than on regular sheets. The same basic design (stamp portion) gets reused for years and only the designs of the pictures and inner stamps change, and sometimes the layout changes (WITHOUT a plate number change).


Souvenir Folders
---
IPC generates these ongoing. There are two types (at least): 
Joint Issue items issued by IPC, usually containing the FE folder, souvenir leaf, and mint items (set or S/S), in a velveteen folder. 
Bigger folders, usually containing a preprinted Bul Sheli sheet and some CDs or other items.

### NOTE ON ID CODE USAGE FOR THESE EXTENSIONS
This can use the refItem field (in INV records) to link these, but ideally that should be in L1 data. In the PHP code, I managed to generate the ID codes for the base set from the given code in the BT data directly. There was one case where a fixup was needed (joint issue item didn't match its base set number for some reason).


Souvenir Leaves
---
In general, these are produced a lot by IPC but I am only interested in those related to Joint Issues. (See which)


Joint Issue items
---
This is a complex topic and I am interested in a lot of it. So much detail needed here.
BT provides some basic data and a numbering scheme that seemed to work for the basics. So my PHP code added a lot of data, but I decided early on there were just too many possible item combinations to deal with. So I created screens that would add L1 data on demand, as the L2 item showed up for entry.
The system was quite complicated, and could generate special coded ID numbers for 6110jNNNxZZZZZ, where the 'x' was the special character indicating my new ID. Tables would allow me to pick all the various item types that were relevant to this particular issue, and generate wants for the things if not directly entering a location.
Moving forward, IPC continues to do 3-4 of these a year, and sometimes the foreign country takes a while to get its issues out. (Ecuador has yet to issue its orchids joint, which Israel came out with last Oct.) Often FDCs are issued by both countries (not always), and even joint FDCs (with both countries items) can have designs by both Israel and the foreign country. So there is rich variety here to support. The Joint Issues category is for all items issued by the foreign government, plus any Israel items that contain both countries' items. Typically I want a Scott catalog number for the foreign stamp when available, although this may take years to find out.


Varieties and Variants
---
The ongoing output from IPC showing up on BT site here includes:
imperf sets, FDCs, sheets, and sheet FDCs taken from collectible printers sheets
self adhesive booklet/sheet individual items (used)

### Update July 2017
A lot of the above features have been implemented or are in process.
Processing continues on the info line downloaded from the BT website that contains data for:
- Dates of issue
- Designer(s)
- Plate number(s)
- Souvenir sheet sizes in cm
- Leaflet (info folder) and bulletin number(s)
- Sheet layout (number of stamps and tabs)
I plan to incorporate these into CoreData extensions and then, at some point, persist them in the CoreData model and backup CSV format (currently, they are downloaded on demand from the web page). This info is for BT dealer site only, not JS.
I have Batch Utility Tasks for generating the missing L1 information for most of these, including the ATM derived data and the Info Folders data. I will add generated Full Sheet info (for the regular 5x3 sheets BT doesn't sell) after I get the Info line info squared away (it is the basis of the extra decriptions).
I need to figure out the following data design issues still:
- Joint items - how to generate and/or make it easy to pick the various items as they come out
- Generic sheets not sold by BT (alternate dates)

Mike Mehr, July 15, 2017

### Update Dec 2023
The original BT website was removed shortly after the proprietor retired in mid-2018.
I was able to download a working copy of the website using HTTrack and have been basing my ongoing usage on that database.

My current architecture is as follows:
- Swift StampCollection app for iOS (this app)
- Webserver app (MySQL, Apache, PHP) to serve the data for the app (now that live access to BT is gone), accessed using nip.io/xip.io
- I have developed a companion website that I serve locally to support adding new data for the system in all the categories which I collect, in the style set by the original site.
-- This admin app (called SIS for Stamp Info System) is separately archived here on Github.
- The creation of ongoing data to augment the original dataset is placed into a separate HTTrack project, and is being adapted to work with the original data in use here.
- The dual database and web server are maintained on a separate computer from the Admin app, explaining the somewhat arcane methods of updating that I currently employ.
So far it is working reasonably well for me, but this is probably not for the faint of heart, however.

Mike Mehr, December 30, 2023
