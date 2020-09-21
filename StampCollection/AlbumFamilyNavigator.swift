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

extension AlbumIndex: Equatable {
    static func == (lhs: AlbumIndex, rhs: AlbumIndex) -> Bool {
        return
            lhs.page == rhs.page &&
                lhs.ref == rhs.ref &&
                lhs.section == rhs.section
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
            print("Cannot find album index \(page.section.ref.code ?? "?section.ref.code?") for page \(page.code ?? "?code?")")
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
            print("Cannot find section index \(page.section.code ?? "?section.code?") for page \(page.code ?? "?code?")")
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
            print("Cannot find page index for page \(page.code ?? "?code?")")
            return nil
        }
        //print("Initpage3/3 \(currentIndex) of \(maxIndex)")
        found = false
    }
    
    /// Summarizes the title for the current page using album and section attributes, suitable for UI titling
    func getCurrentPageTitle() -> String {
        // set the nav bar title to the page/section/ref indicator and show # of items
        let numItems = currentPage.theItems.count
        let albumcode = currentAlbum.displayName
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
    
    func gotoMarkerAcrossVolumes(_ marker: AlbumMarker) {
        let oldMethod = method
        method = .byPagesInSectionAcrossVolumes
        gotoMarker(marker)
        method = oldMethod
    }
    
    func moveToSectionMarker(_ dir: AlbumNavigationDirection) {
        // determine if we are at first or last page of section (marker)
        let marker = currentMarker
        var markerDest = marker
        var useAV = false
        if dir == .forward {
            if marker.contains([.LastSection, .LastPage]) {
                print("NAV/Fwd(Section): Last section, Last pg -> Last album, Last section, Last page")
                useAV = true
                markerDest = [.LastAlbum, .LastSection, .LastPage]
            } else
            if marker.contains(.LastPage) {
                print("NAV/Fwd(Section): Last pg -> Last section, Last page")
                markerDest = [.LastSection, .LastPage]
            } else {
                print("NAV/Fwd(Section): Any pg -> Last page")
                markerDest = .LastPage
            }
        } else if dir == .reverse {
            if marker.contains([.FirstSection, .FirstPage]) {
                print("NAV/Fwd(Section): First section, First pg -> First album, First section, First page")
                useAV = true
                markerDest = [.FirstAlbum, .FirstSection, .FirstPage]
            } else
            if marker.contains(.FirstPage) {
                print("NAV/Rev(Section): First pg -> First section, First page")
                markerDest = [.FirstSection, .FirstPage]
            } else {
                print("NAV/Rev(Section): Any pg -> First page")
                markerDest = .FirstPage
            }
        }
        if useAV {
            gotoMarkerAcrossVolumes(markerDest)
        } else {
            gotoMarker(markerDest)
        }
    }

    func getRefAsData() -> [String:String] {
        var data: [String:String] = [:]
        data["albumPage"] = "\(currentPage.code!)"
        data["albumSection"] = "\(currentPage.section.code!)"
        data["albumFamily"] = "\(currentAlbum.family.code!)"
        data["albumRef"] = "\(currentAlbum.code!)"
        data["albumType"] = "\(currentAlbum.family.type.code!)"
        return data
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
            currentSectionIndex = 0 // sets the first section object as well
        }
    }
    
    fileprivate var currentSectionIndex = 0 {
        didSet {
            currentSection = currentAlbum.theSections[currentSectionIndex]
            // also reset the current page index
            currentPageIndex = 0 // sets the first page object as well
        }
    }
    fileprivate var currentPageIndex = 0 {
        didSet {
            currentPage = currentSection.thePages[currentPageIndex]
        }
    }
    
    fileprivate var currentAlbumIndex: Int {
        get {
            let index = AlbumRef.getIndex(fromRef: currentAlbum.code)
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
    
    var currentMarker: AlbumMarker {
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
    
    func clamp( _ inx: Int, low: Int, hi: Int) -> Int {
        var data = inx
        if data < low { data = low }
        if data > hi  { data = hi }
        return data
    }
    
    func gotoIndex( _ data: AlbumIndex) {
        // when changing more than one currentXXXIndex, they must be done in this order
        currentAlbumIndex = data.ref // may change CSI and CPI, as well as maxSIIA indirectly
        currentSectionIndex = data.section // may change CPI again, as well as maxPIIS indirectly
        currentPageIndex = data.page
    }
    
    func gotoMarker( _ marker: AlbumMarker ) {
        // there is always an album, a section (possibly unnamed), and at least one page defined in every family
        // resolve this in top-down fashion from album thru section to page (property observers would otherwise interfere)
        // NOTE: this is rather inefficient if all bits are set, or both first and last (last will take precedence)
        // first snapshot the current state
        var data = AlbumIndex(ref: currentAlbumIndex, section: currentSectionIndex, page: currentPageIndex)
        // clamp to appropriate limits for each component
        // NOTE: these values in index are ordinal (0 is first item in list of albums/sections/pages, up to N-1 for last)
        let albumCount = currentAlbum.family.theRefs.count // #albums in series/family
        var albumNum = clamp(data.ref, low: 0, hi: albumCount - 1)
        if marker.contains(AlbumMarker.FirstAlbum) {
            albumNum = 0
        }
        if marker.contains(AlbumMarker.LastAlbum) {
            albumNum = albumCount - 1
        }
        let album = currentAlbum.family.theRefs[albumNum]
        let sectionCount = album.theSections.count // #sections in that album
        var sectNum = clamp(data.section, low: 0, hi: sectionCount - 1)
        if marker.contains(AlbumMarker.FirstSection) {
            sectNum = 0
        }
        if marker.contains(AlbumMarker.LastSection) {
            sectNum = sectionCount - 1
        }
        let section = album.theSections[sectNum]
        let pageCount = section.thePages.count // #pages in that section
        var pageNum = clamp(data.page, low: 0, hi: pageCount - 1)
        if marker.contains(AlbumMarker.FirstPage) {
            pageNum = 0
        }
        if marker.contains(AlbumMarker.LastPage) {
            pageNum = pageCount - 1
        }
        data = AlbumIndex(ref: albumNum, section: sectNum, page: pageNum)
        gotoIndex(data)
    }
    
    func gotoEndOfSectionAcrossVolumes() {
        // Unlike gotoMarker(), this function needs to cross marker boundaries and volume boundaries, but keep the same section name as is currently set
        let albumCount = currentAlbum.family.theRefs.count // #albums in series/family
        let albumNum0 = clamp(currentAlbumIndex, low: 0, hi: albumCount - 1) // but why is this needed?
        let secName0 = currentSection.code!
        var albumNumSaved = albumNum0
        var secNumSaved = currentSectionIndex
        for albumNum in albumNum0+1..<albumCount {
            // check existence of section in each subsequent album
            let album = currentAlbum.family.theRefs[albumNum]
            let secMax = album.theSections.count
            // search for current section name in album's list of sections
            for secNum in 0..<secMax {
                let sectionName = album.theSections[secNum].code!
                // if found (album has this section), save it and try the next
                // at end, we'll have the last successful search
                if sectionName == secName0 {
                    albumNumSaved = albumNum
                    secNumSaved = secNum
                }
            }
        }
        // go to first page of identified album and section
        let data = AlbumIndex(ref: albumNumSaved, section: secNumSaved, page: 0)
        gotoIndex(data)
        // then go to last page of that album section
        gotoMarker(.LastPage)
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
