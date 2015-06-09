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
