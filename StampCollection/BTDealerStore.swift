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
    
    fileprivate var JSCategory = BTCategory()
    fileprivate var siteJSHandler = JSMessageDelegate()
    fileprivate var jsProgress: Progress!

    init() {
        siteHandler.delegate = self;
        siteJSHandler.delegate = self;
        JSCategory.number = JSCategoryAll
        JSCategory.name = "(X)Austria Judaica Tabs"
    }

    enum LoadStoreStyle { case justCategories, populate, populateAndWait }
    fileprivate var lsStyle: LoadStoreStyle = .justCategories
    
    func loadStore(_ type: LoadStoreStyle, whenDone: @escaping () -> Void) -> Progress {
        siteProgress = siteHandler.loadCategoriesFromWeb()
        jsProgress = siteJSHandler.loadItemsFromWeb()
        progressCounter = 0 // simpler than array of boolean indicators, for now
        lsStyle = type
        completion = whenDone
        loadingInProgress = true
        return siteProgress
    }
    
    func loadStoreCategory(_ categoryNum: Int, whenDone: @escaping () -> Void) {
        completion = whenDone
        loadMultiple = false
        if categoryNum == JSCategoryAll {
            jsProgress = siteJSHandler.loadItemsFromWeb()
        } else {
            let handler = categoryHandlers[categoryNum]
            let category = getCategoryByNumber(categoryNum)!
            let _/*progress*/ = handler.loadItemsFromWeb(category.href, forCategory: category.number)
            //catProgress.append(progress) // at index categoryNum, as long as we're loading the entire set
        }
        loadingInProgress = true
    }
    
    // MARK: - JSMessageProtocol
    func messageHandler(_ handler: JSMessageDelegate, willLoadDataForCategory category: Int) {
        //print("WillLoad Message received for cat=\(category)")
        JSCategory.dataItems = []
    }
    
    func messageHandler(_ handler: JSMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int) {
        //print("Data Message received for cat=\(category) => \(data)")
        JSCategory.dataItems.append(data)
    }
    
    func messageHandler(_ handler: JSMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int) {
        //print("Update Message received for cat=\(category) => \(data)")
        JSCategory.number = category
        JSCategory.name = "(X)Austria Judaica Tabs"
        JSCategory.headers = data.headers
        JSCategory.notes = data.notes
        JSCategory.items = JSCategory.dataItems.count
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
    
    // MARK: - BTMessageProtocol
    func messageHandler(_ handler: BTMessageDelegate, willLoadDataForCategory category: Int) {
        //print("WillLoad Message received for cat=\(category)")
        if category == BTCategoryAll {
            reloadCategories = []
            categoryHandlers = []
        } else {
            let categoryObject = getReloadCategoryByNumber(category)
            categoryObject.dataItems = []
        }
    }
    
    func messageHandler(_ handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int) {
        //print("Data Message received for cat=\(category) => \(data)")
        if category == BTCategoryAll {
            let dataItem = data as! BTCategory
            let catnum = dataItem.number
            let numItems = Int64(dataItem.items)
           // load each category's basic information, one at a time
            reloadCategories.append(dataItem)
            // create a handler to load the category's items
            let handler = BTMessageDelegate()
            handler.delegate = self
            categoryHandlers.append(handler)
            copyCategoryDataToStore(category, basicOnly: true)
            // trigger the load of this category's item data
            if lsStyle != .justCategories {
                let _/*progress*/ = handler.loadItemsFromWeb(dataItem.href, forCategory: catnum)
                //progress.totalUnitCount = numItems
                //catProgress.append(progress)
                //siteProgress.addChild(progress, withPendingUnitCount: numItems)
                siteProgress.totalUnitCount += numItems
                print("Added progress for \(numItems) items to category \(catnum)--#\(category)")
            }
        } else {
            let dataItem = data as! BTDealerItem
            // load each category's dealer items, one at a time
            let categoryObject = getReloadCategoryByNumber(category)
            categoryObject.dataItems.append(dataItem)
            //catProgress[category-1].completedUnitCount += 1
            siteProgress.completedUnitCount += 1
        }
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
            if let completion = completion , lsStyle != .populateAndWait {
                completion()
            }
        } else if !loadMultiple {
            // we finished loading the items for single category mode
            copyCategoryDataToStore(category, basicOnly: false)
            if let completion = completion {
                completion()
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
                    completion()
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
