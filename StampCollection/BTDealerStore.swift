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

    private var reloadCategories : [BTCategory] = []
    private var siteHandler = BTMessageDelegate()
    private var categoryHandlers : [BTMessageDelegate] = []
    private var progressCounter = 0
    private var progressCounterMax = 0
    private var completion : (() -> Void)?
    private var loadMultiple = true
    private var loadingInProgress = false
    
    private var JSCategory = BTCategory()
    private var siteJSHandler = JSMessageDelegate()

    init() {
        siteHandler.delegate = self;
        siteJSHandler.delegate = self;
        JSCategory.number = JSCategoryAll
        JSCategory.name = "(X)Austria Judaica Tabs"
    }

    enum LoadStoreStyle { case JustCategories, Populate, PopulateAndWait }
    private var lsStyle: LoadStoreStyle = .JustCategories
    
    func loadStore(type: LoadStoreStyle, whenDone: () -> Void) {
        siteHandler.loadCategoriesFromWeb()
        siteJSHandler.loadItemsFromWeb()
        progressCounter = 0 // simpler than array of boolean indicators, for now
        lsStyle = type
        completion = whenDone
        loadingInProgress = true
    }
    
    func loadStoreCategory(categoryNum: Int, whenDone: () -> Void) {
        completion = whenDone
        loadMultiple = false
        if categoryNum == JSCategoryAll {
            siteJSHandler.loadItemsFromWeb()
        } else {
            let handler = categoryHandlers[categoryNum]
            let category = getCategoryByNumber(categoryNum)!
            handler.loadItemsFromWeb(category.href, forCategory: category.number)
        }
        loadingInProgress = true
    }
    
    // MARK: - JSMessageProtocol
    func messageHandler(handler: JSMessageDelegate, willLoadDataForCategory category: Int) {
        //println("WillLoad Message received for cat=\(category)")
        JSCategory.dataItems = []
    }
    
    func messageHandler(handler: JSMessageDelegate, receivedData data: BTDealerItem, forCategory category: Int) {
        //println("Data Message received for cat=\(category) => \(data)")
        JSCategory.dataItems.append(data)
    }
    
    func messageHandler(handler: JSMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int) {
        //println("Update Message received for cat=\(category) => \(data)")
        JSCategory.number = category
        JSCategory.name = "(X)Austria Judaica Tabs"
        JSCategory.headers = data.headers
        JSCategory.notes = data.notes
        JSCategory.items = JSCategory.dataItems.count
    }

    private func jsCompletionRun( catnum: Int16, webJSCategory: BTCategory ) {
        // create a mapping table between website pic refs and persistent pic refs
        // this should be dispatched to a background thread, no completion needed
        let store = BTDealerStore.collection
        let token = store.getNewContextTokenForThread()
        store.addOperationToContext(token) {
            if let jsCategory = store.fetchCategory(catnum, inContext: token) {
                populateJSDictionary(jsCategory, jsWebCat: webJSCategory)
            }
            store.removeContextForThread(token)
        }
    }
    
    func messageHandler(handler: JSMessageDelegate, didLoadDataForCategory category: Int) {
        print("DidLoad Message received for cat=\(category)")
        let catnum = BTCategory.translateNumberToInfoCategory(category)
        jsCompletionRun(catnum, webJSCategory: self.JSCategory)
    }
    
    // MARK: - BTMessageProtocol
    func messageHandler(handler: BTMessageDelegate, willLoadDataForCategory category: Int) {
        //println("WillLoad Message received for cat=\(category)")
        if category == BTCategoryAll {
            reloadCategories = []
            categoryHandlers = []
        } else {
            let categoryObject = getReloadCategoryByNumber(category)
            categoryObject.dataItems = []
        }
    }
    
    func messageHandler(handler: BTMessageDelegate, receivedData data: AnyObject, forCategory category: Int) {
        //println("Data Message received for cat=\(category) => \(data)")
        if category == BTCategoryAll {
            let dataItem = data as! BTCategory
            // load each category's basic information, one at a time
            reloadCategories.append(dataItem)
            // create a handler to load the category's items
            let handler = BTMessageDelegate()
            handler.delegate = self
            categoryHandlers.append(handler)
            copyCategoryDataToStore(category, basicOnly: true)
            // trigger the load of this category's item data
            if lsStyle != .JustCategories {
                handler.loadItemsFromWeb(dataItem.href, forCategory: dataItem.number)
            }
        } else {
            let dataItem = data as! BTDealerItem
            // load each category's dealer items, one at a time
            let categoryObject = getReloadCategoryByNumber(category)
            categoryObject.dataItems.append(dataItem)
        }
    }

    func messageHandler(handler: BTMessageDelegate, receivedUpdate data: BTCategory, forCategory category: Int) {
        //println("Update Message received for cat=\(category) => \(data)")
        let categoryObject = getReloadCategoryByNumber(category)
        // update the headers and notes properties (nothing else is guaranteed to be set here)
        categoryObject.headers = data.headers
        categoryObject.notes = data.notes
    }
    
    func messageHandler(handler: BTMessageDelegate, didLoadDataForCategory category: Int) {
        //println("DidLoad Message received for cat=\(category)")
        if category == BTCategoryAll {
            // we just finished loading the master category data
            // load the progress counter's done indicator (how many categories have to load their data items)
            progressCounterMax = reloadCategories.count
            // data copying: for .JustCategories, we only want to copy the basic category data to the store, where present
            if lsStyle != .PopulateAndWait {
                copyCategoryDataToStore(category, basicOnly: true)
            }
            // run the completion routine here for styles .JustCategories and .Populate
            if let completion = completion where lsStyle != .PopulateAndWait {
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
            ++progressCounter
            // update the store item data for this category
            if lsStyle != .JustCategories {
                copyCategoryDataToStore(category, basicOnly: false)
            }
            if progressCounterMax > 0 && progressCounter == progressCounterMax {
                // we just loaded the last of the data items from the site
                progressCounter = progressCounterMax
                // run the completion routine here for style .PopulateAndWait
                if let completion = completion where lsStyle == .PopulateAndWait {
                    completion()
                }
                loadingInProgress = false
            }
        }
    }

    // MARK: utility functions
    private func copyCategoryDataToStore(category: Int, basicOnly: Bool) {
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
    
    private func getReloadCategoryByNumber( num: Int ) -> BTCategory {
        return reloadCategories[num-1]
    }
    
    func getCategoryByNumber( num: Int ) -> BTCategory? {
        if num == JSCategoryAll {
            return JSCategory
        }
        return categories.filter{
            $0.number == num
        }.first
    }
    
    func getCategoryByIndex( num: Int ) -> BTCategory {
        if num == -1 {
            return JSCategory
        }
        return categories[num]
    }
    
    func exportData( completion: (() -> Void)? = nil ) {
        let exporter = BTExporter()
        let data = categories + [JSCategory]
        exporter.exportData(data, completion: completion)
    }
    
    func importData( completion: (() -> Void)? = nil ) {
        print("Importing data from CSV files")
        let importer = BTImporter()
        importer.importData() {
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
    }
}