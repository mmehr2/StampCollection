//
//  AlbumFamilyNavigator.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/4/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

struct AlbumIndex {
    let ref: Int
    let section: Int
    let page: Int
}

extension AlbumIndex: CustomStringConvertible {
    var description: String {
        return "Album#\(ref+1) Sec#\(section+1) Page#\(page+1)"
    }
}

enum AlbumNavigationDirection {
    case forward, reverse
}


typealias SwiftOptionRawType = UInt32 // this changed between Swift 1.2(Int), 2.0(Int32), and XCode 7.0.1(UInt32) [OH APPLE!] UInt64 anyone?

struct AlbumMarker: OptionSet {
    let rawValue: SwiftOptionRawType
    init(rawValue: SwiftOptionRawType) { self.rawValue = rawValue }
    
    static let FirstAlbum = AlbumMarker(rawValue: 1 << 0 as SwiftOptionRawType) // first album in series
    static let LastAlbum = AlbumMarker(rawValue: 1 << 1 as SwiftOptionRawType) // last album in series
    static let FirstSection = AlbumMarker(rawValue: 1 << 2 as SwiftOptionRawType) // first section in album
    static let LastSection = AlbumMarker(rawValue: 1 << 3 as SwiftOptionRawType) // last section in album
    static let FirstPage = AlbumMarker(rawValue: 1 << 4 as SwiftOptionRawType) // first page in section
    static let LastPage = AlbumMarker(rawValue: 1 << 5 as SwiftOptionRawType) // last page in section
    
    static let SeriesStart: AlbumMarker = [FirstAlbum, FirstSection, FirstPage]
    static let SeriesEnd: AlbumMarker = [LastAlbum, LastSection, LastPage]
    static let CurrentAlbumStart: AlbumMarker = [FirstSection, FirstPage]
    static let CurrentAlbumEnd: AlbumMarker = [LastSection, LastPage]

    static let SingleAlbumOnly: AlbumMarker = [FirstAlbum, LastAlbum]
    static let SingleSectionOnly: AlbumMarker = [FirstSection, LastSection]
    static let SinglePageOnly: AlbumMarker = [FirstPage, LastPage]
}

/**
 Album navigation proceeds by advancing through pages as if they were organized in a linear fashion.
 
 The methods currently provided fit the album sections together in certain ways.
 
 The default method (AcrossSections) will page through a volume in physical order. When the end of one section
   is encountered, it will proceed with the first page in the next section of the volume, if any. Once all the
   sections are exhausted, it will then proceed to the first page of the first section of the next volume.
 
 The AcrossVolumes method will remain within a single section, moving across volume boundaries in order to keep
   the current page within that section.
 */
enum AlbumNavigationMethod {
    case byPagesInVolumeAcrossSections // default - through all sections within a volume, then onto the next
    case byPagesInSectionAcrossVolumes // confined to same section within all volumes of a family series
}

class AlbumFamilyNavigator {

    // MARK: accessible interface
    init(album: AlbumRef) {
        currentAlbum = album
        gotoMarker(AlbumMarker.CurrentAlbumStart)
    }

    init?(page: AlbumPage) {
        currentAlbum = page.section.ref
        var found = false
        for (index, item) in currentAlbum.family.theRefs.enumerated() {
            if item === currentAlbum {
                currentAlbumIndex = index
                found = true
            }
        }
        if !found {
            print("Cannot find album index \(page.section.ref.code) for page \(page.code)")
            return nil
        }
        //print("Initpage1/3 \(currentIndex) of \(maxIndex)")
        found = false
        currentSection = page.section
        for (index, item) in currentAlbum.theSections.enumerated() {
            if item === currentSection {
                currentSectionIndex = index
                found = true
            }
        }
        if !found {
            print("Cannot find section index \(page.section.code) for page \(page.code)")
            return nil
        }
        //print("Initpage2/3 \(currentIndex) of \(maxIndex)")
        found = false
        currentPage = page
        for (index, item) in currentSection.thePages.enumerated() {
            if item === currentPage {
                currentPageIndex = index
                found = true
            }
        }
        if !found {
            print("Cannot find page index for page \(page.code)")
            return nil
        }
        //print("Initpage3/3 \(currentIndex) of \(maxIndex)")
        found = false
    }
    
    /// Summarizes the title for the current page using album and section attributes, suitable for UI titling
    func getCurrentPageTitle() -> String {
        // set the nav bar title to the page/section/ref indicator and show # of items
        let numItems = currentPage.theItems.count
        let albumcode = currentAlbum.code ?? ""
        let sectioncode = currentSection.code ?? ""
        let pagenum = currentPage.code ?? ""
        let optionalSection = sectioncode == "" ? "" : "[\(sectioncode)] "
        let title = "\(albumcode) \(optionalSection)Page \(pagenum) - \(numItems) items"
        return title
    }
    
    var currentIndex: AlbumIndex {
        return AlbumIndex(ref: currentAlbumIndex, section: currentSectionIndex, page: currentPageIndex)
    }
    
    var maxIndex: AlbumIndex {
        return AlbumIndex(ref: maxAlbumIndex-1, section: maxSectionIndexInAlbum-1, page: maxPageIndexInSection-1)
    }
    
    var method: AlbumNavigationMethod = .byPagesInVolumeAcrossSections
    
    func movePageRelative( _ direction: AlbumNavigationDirection, byCount: Int = 1 ) {
        switch direction {
        case .forward: gotoNextPage(byCount)
        case .reverse: gotoPrevPage(byCount)
        }
    }
    
    func gotoEndOfAlbum() {
        gotoMarker(AlbumMarker.CurrentAlbumEnd)
    }

    // MARK: implementation properties
    /*
    NOTE: The album can have multiple sections, and each one multiple pages.
    We only want to display the contents of one page at a time here. Other controllers will deal with bulk page operations, such as renumbering or moving between albums.
    We need an operation to move to the next page or previous page, continuing when we hit the end of a section (start or stop) in this album ref.
    Some nice-to-have ops would be FirstPageOfSection (to browse) and LastPageOfSection (to add new ones) too.
    Might we not also want to switch to previous or next ref in our parent family when trying to exit the album? Hmmm...
    We also need an operation to switch sections, if there are more than one.
    Finally, we need operations to edit the current page, or add a new page. Page deletion will be unlikely, but must follow strict protocols (all objects moved away).
    
    So, how to tell which page we are on? We need a section/page# pair, sounds like an NSIndexPath of sorts. Actual access should come from this ref via the album object's theSections array.
    */
    
    fileprivate var currentAlbum: AlbumRef! {
        didSet {
            //maxSectionIndex = currentAlbum.theSections.count
            currentSectionIndex = 0
        }
    }
    
    fileprivate var currentSectionIndex = 0 {
        didSet {
            currentSection = currentAlbum.theSections[currentSectionIndex]
            // also reset the current page index
            currentPageIndex = 0 // sets a page object as well
        }
    }
    fileprivate var currentPageIndex = 0 {
        didSet {
            currentPage = currentSection.thePages[currentPageIndex]
        }
    }
    
    fileprivate var currentAlbumIndex: Int {
        get {
            let (_, index) = splitNumericEndOfString(currentAlbum.code)
            guard let result = Int(index) else { return 0 }
            return result - 1
        }
        set {
            currentAlbum = currentAlbum.family.theRefs[newValue]
        }
    }
    
    fileprivate var maxAlbumIndex: Int {
        return currentAlbum.family.theRefs.count
    }
    
    fileprivate var maxSectionIndexInAlbum: Int {
        return currentAlbum.theSections.count
    }
    
    //private var maxSectionIndex = 0
    fileprivate var maxPageIndexInSection: Int {
        return currentSection.thePages.count
    }
    
    fileprivate var currentSection: AlbumSection!
    var currentPage: AlbumPage!
    
    fileprivate var currentMarker: AlbumMarker {
        var mark = AlbumMarker()
        // add options for special cases
        let effectiveAlbumIndex = currentAlbumIndex 
        if effectiveAlbumIndex == 0 {
            mark.insert(AlbumMarker.FirstAlbum)
        }
        if effectiveAlbumIndex == maxAlbumIndex - 1 {
            mark.insert(AlbumMarker.LastAlbum)
        }
        if currentSectionIndex == 0 {
            mark.insert(AlbumMarker.FirstSection)
        }
        if currentSectionIndex == maxSectionIndexInAlbum - 1 {
            mark.insert(AlbumMarker.LastSection)
        }
        if currentPageIndex == 0 {
            mark.insert(AlbumMarker.FirstPage)
        }
        if currentPageIndex == maxPageIndexInSection - 1 {
            mark.insert(AlbumMarker.LastPage)
        }
        return mark
    }
    
    fileprivate func gotoMarker( _ marker: AlbumMarker ) {
        // there is always an album, a section (possibly unnamed), and at least one page defined in every family
        // resolve this in top-down fashion from album thru section to page (property observers would otherwise interfere)
        // NOTE: this is rather inefficient if all bits are set, or both first and last (last will take precedence)
        if marker.contains(AlbumMarker.FirstAlbum) {
            currentAlbumIndex = 0
        }
        if marker.contains(AlbumMarker.LastAlbum) {
            currentAlbumIndex = maxAlbumIndex - 1
        }
        if marker.contains(AlbumMarker.FirstSection) {
            currentSectionIndex = 0
        }
        if marker.contains(AlbumMarker.LastSection) {
            currentSectionIndex = maxSectionIndexInAlbum - 1
        }
        if marker.contains(AlbumMarker.FirstPage) {
            currentPageIndex = 0
        }
        if marker.contains(AlbumMarker.LastPage) {
            currentPageIndex = maxPageIndexInSection - 1
        }
        print("\(currentIndex) of \(maxIndex)")
    }
    
    // MARK: navigating the album hierarchy by pages
    // This type of nav is extended to go thru section and ref boundaries as if browsing one big book
    fileprivate func gotoNextPage(_ by: Int = 1) {
        let next = currentPageIndex + by
        if (0 ..< maxPageIndexInSection).contains(next) {
            currentPageIndex = next
            print("Set page index to \(currentPageIndex)")
        } else {
            print("Reached end of section")
            gotoNextSection()
        }
        print("\(currentIndex) of \(maxIndex)")
    }
    
    fileprivate func gotoPrevPage(_ by: Int = 1) {
        let next = currentPageIndex - by
        if (0 ..< maxPageIndexInSection).contains(next) {
            currentPageIndex = next
            print("Set page index to \(currentPageIndex)")
        } else {
            print("Reached start of section")
            gotoPrevSection()
        }
        print("\(currentIndex) of \(maxIndex)")
    }
    
    fileprivate func gotoNextSection() {
        let next = currentSectionIndex + 1
        if next < maxSectionIndexInAlbum {
            currentSectionIndex = next
            print("Set section index to \(currentSectionIndex)")
        } else {
            print("Reached end of album")
            gotoNextAlbum()
        }
    }
    
    fileprivate func gotoPrevSection() {
        let next = currentSectionIndex - 1
        if next >= 0 {
            currentSectionIndex = next
            gotoMarker(AlbumMarker.LastPage)
            print("Set section index to \(currentSectionIndex)")
        } else {
            print("Reached start of album")
            gotoPrevAlbum()
        }
    }
    
    fileprivate func gotoNextAlbum() {
        if currentMarker.contains(AlbumMarker.SingleAlbumOnly) {
            print("Singleton album not a series, cannot goto next.")
            return
        }
        let next = currentAlbumIndex + 1
        if next < maxAlbumIndex {
            currentAlbumIndex = next
            print("Set album index to \(currentAlbumIndex)")
        } else {
            print("Reached end of series")
        }
    }
    
    fileprivate func gotoPrevAlbum() {
        if currentMarker.contains(AlbumMarker.SingleAlbumOnly) {
            print("Singleton album not a series, cannot goto previous.")
            return
        }
        let next = currentAlbumIndex - 1
        if next >= 0 {
            currentAlbumIndex = next
            gotoMarker(AlbumMarker.CurrentAlbumEnd)
            print("Set album index to \(currentAlbumIndex)")
        } else {
            print("Reached start of series")
        }
    }
    
}
