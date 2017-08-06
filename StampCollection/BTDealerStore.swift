//
//  BTDealerStore.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation

// this class organizes all the data retrieved from external dealer Bait-tov.com's website
// UPDATE: additional category added for Judaicasales.com's website (Austria tabs)

// UPDATE ON PIC IMAGES:
/*
I have determined that the pics can be downloaded from BT site using URLs like these: http://www.bait-tov.com/store/products/6110s555.jpg
The entire user-viewed page comes from URLs like these: http://www.bait-tov.com/store/pic.php?ID= and then append the ID portion (minus the .jpg extension).
I have already downloaded the pics from the JS website, files of the form ajtXX.jpg
All I need to learn is how to cache them in CoreData, and then how to provide that properly (Bundle?) as startup data for the initial app setup.
Only for my private use, of course. This app should never ship.
*/

class BTDealerStore: BTMessageProtocol, JSMessageProtocol {
    static let model = BTDealerStore() // singleton/global model item
    static var collection: CollectionStore! // kludge to get JS pic fixup info
    
    var categories : [BTCategory] = []
    
    var loading : Bool {
        return loadingInProgress
    }

    fileprivate var reloadCategories : [BTCategory] = []
    fileprivate var siteHandler = BTMessageDelegate()
    fileprivate var categoryHandlers : [BTMessageDelegate] = []
    fileprivate var progressCounter = 0
    fileprivate var progressCounterMax = 0
    fileprivate var completion : (() -> Void)?
    fileprivate var loadMultiple = true
    fileprivate var loadingInProgress = false
    fileprivate var siteProgress: Progress!
    //fileprivate var catProgress: [Progress] = []
    fileprivate var detailer: BTItemDetailsLoader?
    
    fileprivate var JSCategory = BTCategory()
    fileprivate var siteJSHandler = JSMessageDelegate()
    fileprivate var jsProgress: Progress!
    fileprivate var startQueue = DispatchQueue.main
    fileprivate var utilQueue = DispatchQueue.global(qos: .background)
    //fileprivate var utilQueue = DispatchQueue(label: "com.azuresults.StampCollection.qUtil", qos: .utility, attributes: .concurrent)

    init() {
        siteHandler.delegate = self;
        siteJSHandler.delegate = self;
        JSCategory.number = JSCategoryAll
        JSCategory.name = "(X)Austria Judaica Tabs"
    }

    enum LoadStoreStyle { case justCategories, populate, populateAndWait }
    fileprivate var lsStyle: LoadStoreStyle = .justCategories
    
    func loadStore(_ type: LoadStoreStyle, whenDone: @escaping () -> Void) -> Progress {
        siteProgress = Progress()
        progressCounter = 0 // simpler than array of boolean indicators, for now
        lsStyle = type
        completion = whenDone
        loadingInProgress = true
        siteHandler.configToLoadCategoriesFromWeb()
        siteJSHandler.configToLoadItemsFromWeb()
        startQueue.async{
            self.siteHandler.run()
            self.siteJSHandler.run()
        }
        return siteProgress
    }
    
    func loadStoreCategory(_ categoryNum: Int, whenDone: @escaping () -> Void) -> Progress {
        siteProgress = Progress()
        siteProgress.totalUnitCount = 1
        guard let categ = getCategoryByNumber(categoryNum) else {
            // categories have not been loaded the 1st time yet - TBD: should do a 1st-time load
            print("Unable to reload individual category \(categoryNum) - object not found.")
            siteProgress.completedUnitCount = siteProgress.totalUnitCount
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
                self.completion = nil // release memory ref after this use rather than waiting till next use
            }
            return siteProgress
        }
        // estimated count is the same as before
        siteProgress.totalUnitCount = Int64(categ.dataItemCount)
        completion = whenDone
        loadMultiple = false
        if categoryNum == JSCategoryAll {
            self.siteJSHandler.configToLoadItemsFromWeb()
            startQueue.async(execute: self.siteJSHandler.run)
        } else {
            // TBD - make sure categoryHandlers[] and reloadCatetories[] are loaded
            // (typical use after import - NOT; but OK for intended use after loadStore(NOT.justCategories) has been done once)
            guard !categoryHandlers.isEmpty && !reloadCategories.isEmpty else {
                print("Unable to reload individual category \(categoryNum) - object arrays not found.")
                siteProgress.completedUnitCount = siteProgress.totalUnitCount
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                    self.completion = nil // release memory ref after this use rather than waiting till next use
                }
                return siteProgress
            }
            let handler = self.categoryHandlers[categoryNum]
            let category = self.getCategoryByNumber(categoryNum)!
            handler.configToLoadItemsFromWeb(category.href, forCategory: category.number)
            startQueue.async(execute: handler.run)
        }
        loadingInProgress = true
        return siteProgress
    }
    
    func loadDataDetails(_ whenDone: @escaping () -> Void) -> Progress {
        siteProgress = Progress()
        siteProgress.totalUnitCount = 1
        completion = whenDone
        guard let detailer = self.detailer else {
            print("Unable to start Sets Category detail loader, object not found.")
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
                self.completion = nil // release memory ref after this use rather than waiting till next use
            }
            return siteProgress
        }
//        progressCounter = 0 // simpler than array of boolean indicators, for now
//        loadingInProgress = true
        // transfer responsibility for completion to the detailer
        detailer.completion = completion
        completion = nil
        startQueue.async{
            detailer.run()
        }
        return detailer.progress
    }
    
    func cancelLoadDetails() {
        if let detailer = detailer {
            detailer.cancel()
        }
    }
    
    // MARK: - JSMessageProtocol
    func messageHandler(_ handler: JSMessageDelegate, willLoadDataForCategory category: Int) {
        //print("WillLoad Message received for cat=\(category)")
        JSCategory.resetDataItems()
    }
    
    func messageHandler(_ handler: JSMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int) {
        //print("Data Message received for cat=\(category) => \(data)")
        JSCategory.addDataItem(data)
    }
    
    func messageHandler(_ handler: JSMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int) {
        //print("Update Message received for cat=\(category) => \(data)")
        JSCategory.number = category
        JSCategory.name = "(X)Austria Judaica Tabs"
        JSCategory.headers = data.headers
        JSCategory.notes = data.notes
        JSCategory.items = JSCategory.dataItemCount
    }

    fileprivate func jsCompletionRun( _ catnum: Int16, webJSCategory: BTCategory ) {
        // create a mapping table between website pic refs and persistent pic refs
        // this should be dispatched to a background thread, no completion needed
        guard let store = BTDealerStore.collection else { return }
        let token = store.getNewContextTokenForThread()
        store.addOperationToContext(token) {
            if let jsCategory = store.fetchCategory(catnum, inContext: token) {
                populateJSDictionary(jsCategory, jsWebCat: webJSCategory)
            }
            store.removeContextForThread(token)
        }
    }
    
    func messageHandler(_ handler: JSMessageDelegate, didLoadDataForCategory category: Int) {
        //print("DidLoad Message received for cat=\(category)")
        let catnum = BTCategory.translateNumberToInfoCategory(category)
        jsCompletionRun(catnum, webJSCategory: self.JSCategory)
    }
    
    // MARK: - BTInfoProtocol
    func messageHandler(_ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int) {
        // find the BTDealerItem from the handler and set its details field to the data
        // sanity check: should be for category 2
        guard category == Int(CATEG_SETS) else {
            print("Received details item outside of category 2 = \(category)")
            return
        }
        let urlcodeX = handler.url.absoluteString.components(separatedBy: "=")
        guard let code = urlcodeX.last, code.hasPrefix("6110s") else {
            print("Received non-category item from cat 2 = \(urlcodeX.last ?? "")")
            return
        }
        // remember, during the load process, we use the backup store categories
        let cat = getReloadCategoryByNumber(Int(CATEG_SETS))
        if let btitem = cat.fetchData(withCode: code) {
            //print("Assigned detail item to item \(btitem.code) (\(btitem.descr)): data:[\(data)]")
            btitem.details = data
        } else {
            print("Couldn't find BT item to assign data with code \(code) to: \(data)")
        }
    }
    
    // MARK: - BTMessageProtocol
    func messageHandler(_ handler: BTMessageDelegate, willLoadDataForCategory category: Int) {
        print("WillLoad Message received for cat=\(category)")
        if category == BTCategoryAll {
            reloadCategories = []
            categoryHandlers = []
            detailer = nil
        } else {
            let categoryObject = getReloadCategoryByNumber(category)
            categoryObject.resetDataItems()
        }
    }
    
    func messageHandler(_ handler: BTMessageDelegate, receivedCategoryData dataItem: BTCategory, forCategory category: Int) {
        //print("Data Message received for cat=\(category) => \(data)")
        if category == BTCategoryAll {
            let catnum = dataItem.number
            let catname = dataItem.name
            let numItems = Int64(dataItem.items)
            // load each category's basic information, one at a time
            reloadCategories.append(dataItem)
            copyCategoryDataToStore(category, basicOnly: true)
            // trigger the load of this category's item data
            if lsStyle != .justCategories {
                DispatchQueue.main.async {
                    // create a handler to load the category's items (must run on main thread for hidden WK UI)
                    let handler = BTMessageDelegate()
                    handler.delegate = self
                    self.categoryHandlers.append(handler)
                    handler.configToLoadItemsFromWeb("http://www.google.com", forCategory: catnum) // dummy URL will be replaced
                    print("Loaded category handler for Category \(catnum): \(catname)")
                    // create the detail loader for set info details
                    if Int16(catnum) == CATEG_SETS {
                        self.detailer = BTItemDetailsLoader()
                        if let detailer = self.detailer {
                            // set ourselves up to receive info details messages
                            detailer.delegate = self
                        }
                        print("Added ItemDetails Loader for category \(catnum): \(catname)")
                    }
                    self.utilQueue.async {
                        handler.url = URL(string: dataItem.href)
                        handler.run()
                    }
                    self.siteProgress.totalUnitCount += numItems
                    print("Added progress for \(numItems) items to category \(catnum): \(catname)")
                }
            }
        }
    }
    
    
    func messageHandler(_ handler: BTMessageDelegate, receivedData dataItem: BTDealerItem, forCategory category: Int) {
        // load each category's dealer items, one at a time
        let categoryObject = getReloadCategoryByNumber(category)
        categoryObject.addDataItem(dataItem)
        //catProgress[category-1].completedUnitCount += 1
        let allowDetailsSet = Int16(category) == CATEG_SETS
        let allowDetailsDebug = false // set this to TRUE to enable debug year limits for testing (else entire set list will be loaded)
        // DEBUG - limit number of items by year for testing the mechanism
        let allowDetailsYear: Bool
        let year = Int(String(dataItem.descr.characters.prefix(4)))
        let limitYearRange = 1948...2017 // TEST: <1948, 0 sets; <1949, 4 sets, <1950, 11 sets
        if let year = year, limitYearRange.contains(year) {
            allowDetailsYear = true
        } else {
            allowDetailsYear = false
        }
        let allowDetailsPolicy = allowDetailsDebug ? (allowDetailsYear && allowDetailsSet) : allowDetailsSet
        if let detailer = detailer, let href = dataItem.picPageURL?.absoluteString, allowDetailsPolicy {
            // add and remember a detail loader item for this dataItem
            let added = detailer.addItem(withHref: href)
            if added {
                print("Added item #\(detailer.count) to detailer: details at \(href)")
            }
        }
        siteProgress.completedUnitCount += 1
    }

    func messageHandler(_ handler: BTMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int) {
        //print("Update Message received for cat=\(category) => \(data)")
        let categoryObject = getReloadCategoryByNumber(category)
        // update the headers and notes properties (nothing else is guaranteed to be set here)
        categoryObject.headers = data.headers
        categoryObject.notes = data.notes
    }
    
    fileprivate var lastRecvd: Int64 = 0
    
    func messageHandler(_ handler: BTMessageDelegate, didLoadDataForCategory category: Int) {
        let addedData = siteProgress.completedUnitCount - lastRecvd
        let added = category < 0 ? "" : " (added \(addedData))"
        print("DidLoad Message received for cat=\(category): prog=\(siteProgress.completedUnitCount) of \(siteProgress.totalUnitCount)\(added)")
        lastRecvd = siteProgress.completedUnitCount
        if category == BTCategoryAll {
            // we just finished loading the master category data
            // load the progress counter's done indicator (how many categories have to load their data items)
            progressCounterMax = reloadCategories.count
            // data copying: for .JustCategories, we only want to copy the basic category data to the store, where present
            if lsStyle != .populateAndWait {
                copyCategoryDataToStore(category, basicOnly: true)
            }
            // run the completion routine here for styles .JustCategories and .Populate
            if lsStyle != .populateAndWait {
                if let completion = completion {
                    DispatchQueue.main.async(execute: completion)
                    self.completion = nil // release memory ref after this use rather than waiting till next use
                }
            }
        } else if !loadMultiple {
            // we finished loading the items for single category mode
            copyCategoryDataToStore(category, basicOnly: false)
            if let completion = completion {
                DispatchQueue.main.async(execute: completion)
                self.completion = nil // release memory ref after this use rather than waiting till next use
            }
            loadingInProgress = false
        } else {
            // we just loaded another category's data items in multiple mode
            // count the category
            progressCounter += 1
            // update the store item data for this category
            if lsStyle != .justCategories {
                copyCategoryDataToStore(category, basicOnly: false)
            }
            if progressCounterMax > 0 && progressCounter == progressCounterMax {
                // we just loaded the last of the data items from the site
                progressCounter = progressCounterMax
                // run the completion routine here for style .PopulateAndWait
                if let completion = completion , lsStyle == .populateAndWait {
                    DispatchQueue.main.async(execute: completion)
                    self.completion = nil // release memory ref after this use rather than waiting till next use
                }
                loadingInProgress = false
            }
        }
    }

    // MARK: utility functions
    fileprivate func copyCategoryDataToStore(_ category: Int, basicOnly: Bool) {
        if category == BTCategoryAll {
            for cat in reloadCategories {
                copyCategoryDataToStore(cat.number, basicOnly: basicOnly)
            }
        } else if category > categories.count {
            let rlc = getReloadCategoryByNumber(category)
            categories.append(rlc)
        } else {
            let rlc = getReloadCategoryByNumber(category)
            let cat = getCategoryByNumber(category)!
            if basicOnly && rlc.number == cat.number {
                BTCategory.copyBasicDataFrom(rlc, toCategoryObject: cat)
            } else {
                categories[category-1] = rlc
            }
        }
    }
    
    fileprivate func getReloadCategoryByNumber( _ num: Int ) -> BTCategory {
        return reloadCategories[num-1]
    }
    
    func getCategoryByNumber( _ num: Int ) -> BTCategory? {
        if num == JSCategoryAll {
            return JSCategory
        }
        return categories.filter{
            $0.number == num
        }.first
    }
    
    func getCategoryByIndex( _ num: Int ) -> BTCategory {
        if num == -1 {
            return JSCategory
        }
        return categories[num]
    }
    
    func exportData( _ completion: (() -> Void)? = nil ) -> Progress {
        let exporter = BTExporter()
        let data = categories + [JSCategory]
        let progress = exporter.exportData(data, completion: completion)
        return progress
    }
    
    func importData( _ completion: (() -> Void)? = nil ) -> Progress {
        print("Importing data from CSV files")
        let importer = BTImporter()
        let progress = importer.importData() {
            // when it's done, we need to copy the data out
            // NOTE: this is already running on the UI thread (completion block from importData())
            self.categories = importer.getBTCategories()
            if let jsc = importer.getJSCategory() {
                self.JSCategory = jsc
                self.jsCompletionRun(CATNUM_AUSTRIAN, webJSCategory: jsc)
            }
            // and then call the completion routine
            if let completion = completion {
                completion()
            }
        }
        return progress
    }
}
