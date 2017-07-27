//
//  BTItemDetailsLoader.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/21/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation
import GameKit // for random functions

// class that is responsible for loading item details to go with BTDealerItems in category 2 (Sets)
// these are done by running a dedicated BTMessageDelegate for each item
// Usage Scenario:
//   Caller creates loader, specifying a completion handler to run at the end.
//   Caller can also specify a delegate to receive the detail items.
//   Optionally, the caller can adjust the batch size and frequency (time in secs between batches)
//
//   Caller adds items one by one as the dealer items are downloaded (assumed category 2 Sets)
//      This is done using the addItem() function, passing the href of the pic page URL
//
//   Once all items have been loaded, the caller calls run() to start batch sending of web requests.
//   This will call runInfo() in batches on all items until all have been processed.
//
//   At the end, when no more items are left, the completion handler is run on the main queue
//   At any given time, the progress.totalUnitCount tells how many items are being processed,
//      and progress.completedUnitCount will return how many have been done so far.
//   The property count will specify how many are left to receive results for.
//
// Architecture Update:
/*
 To reduce memory footprint and allow the function to work on small-memory devices, we need to think about having 1100+ objects.
 After some thought, it seems best to do the following:
 1. Modify the setup to create a pool of batchSize handlers (BTMessageDelegate) that point to this for info message replies
 2. Configure these objects for BTItemDetails usage (MUST BE DONE ON MAIN THREAD)
 3. Redo items and batch to be Set<String> or Set<Int> (id code or just the numeric part)
 4. At addItem() time, save only the number or code
 5. At runtime, for each individual number, reconstruct the href, rewrite the url, and invoke runInfo()
 6. *** I believe this will also require a mod to the handler (add an ID number) so that routing works downstream.
 
 To address the final point, the BTDealerStore has used the identity of the (up until now) unique handler to key its lookup for the intended destination object (BTDealerItem) for the detail response to attach to.
 Now that the handler objects will be no longer unique, we need to provide a way to find the BTDealerItem.
 After trying several ideas, I believe the solution is to provide the ability to look up the BTDealerItem objects by code in the category object they are associated with (and downloaded using). This turns out to require a lot less code than I thought, and also will preclude the need to do any kind of routing. If the code can be reconstructed from the handler URL, then the item can be retrieved. This is easily done since the code is used directly in the URL href (last component after the '=' in the pic.php URL.
 */

/*
 DEMO MODE -
 The loader operation can be tested by setting the demo flag to true before calling run().
 A demo run will call all the logic except the async code dispatch to actually load the items.
 Console printouts will indicate the order of handler assignment, object running, and whether or not the completion is called.
 */

/*
 INTENT TO RANDOMIZE
 Once I am confident that the scheme will work, I intend to randomly perturb both the batchSize (up to the poolSize) and the inter-batch delay factor to avoid deluging the internet with traffic and/or triggering anti-spam blocking behavior on the site. Perhaps this is also needed in the item download, will consider adapting this scheme later for category item use.
 */

class BTItemDetailsLoader: BTInfoProtocol {

    var demo: Bool = false
    let progress: Progress
    var delegate: BTInfoProtocol?
    var completion: (() -> Void)?
    var batchSize = 10
    var timeInterval: TimeInterval = 2.0 // secs delay from when batch is emptied and starts to send again
    
    var count: Int {
        return items.count
    }
    var remainingItemsCount: Int {
        return items.endIndex - currentBatchStart
    }
    var remainingBatchItemsCount: Int {
        return currentBatchEnd - currentBatchStart
    }
    var moreWork: Bool {
        return remainingItemsCount > 0 || remainingBatchItemsCount > 0
    }
    
    private var handlers: [BTMessageDelegate] = []
    private var currentHandler: Array<BTMessageDelegate>.Index
    
    private let queue: DispatchQueue
    private typealias ItemCollection = Array<Int16>
    private var items = ItemCollection()
    private var currentBatchStart: ItemCollection.Index
    private var currentBatchEnd: ItemCollection.Index
    private var addDelay = false
    
    private func firstItem() {
        currentBatchStart = items.startIndex
        currentBatchEnd = currentBatchStart
        nextBatch()
    }
    
    private func nextItem() {
        currentBatchStart = items.index(currentBatchStart, offsetBy: 1)
    }
    
    private func nextBatch() {
        if let cbe = items.index(currentBatchEnd, offsetBy: batchSize, limitedBy: items.endIndex) {
            currentBatchEnd = cbe
        } else {
            currentBatchEnd = items.endIndex
        }
    }
    
    init(_ comp: (() -> Void)? = nil) {
        progress = Progress()
        // the queue operates as a serial queue, so items are requested
        queue = DispatchQueue(label: "com.azuresults.BTLoadDetailsQueue", qos: .background)
        completion = comp
        currentBatchStart = items.startIndex
        currentBatchEnd = currentBatchStart
        // initial index is array start
        currentHandler = handlers.startIndex
        // set up the pool of handler objects: configure each to talk back to us for details usage
        // NOTE: this object must be created on the main thread; else there must be a configure() function to do this
        configureHandlers()
        // set up the window (for empty array) so that we can always call run()
        firstItem()
    }
    
    private func configureHandlers() {
        // create a pool of batchSize length containing handlers of class BTMessageDelegate
        print("Configuring pool of \(batchSize) message delegates")
        for _ in 0..<batchSize {
            let handler = BTMessageDelegate()
            // point the handler to us so we get message traffic
            handler.delegate = self
            // configure the hidden UI of the webpage proxy
            handler.configToLoadItemsFromWeb(BTURLPlaceHolder, forCategory: Int(CATEG_SETS))
            handlers.append(handler)
        }
    }
    
    private func getNextHandler() -> BTMessageDelegate {
        // result is current handler
        let result = handlers[currentHandler]
        let hd = currentHandler - handlers.startIndex
        print("Assigning handler #\(hd+1)")
        // bump current handler pointer (implements round-robin dispatcher for handler pool)
        currentHandler = handlers.index(currentHandler, offsetBy: 1)
        if currentHandler == handlers.endIndex {
            currentHandler = handlers.startIndex
        }
        return result
    }

    // ** The client calls this to add a new item href to the list of details to load
    func addItem(withHref href: String) {
        let codeNum = getCodeNumber(fromHref: href)
        if codeNum > 0 {
            items.append(codeNum)
            progress.totalUnitCount += 1
            // update initial window so we are always ready to have run() called
            firstItem()
        }
    }
    
    private func getURL(fromCodeNumber cnum: Int16) -> URL {
        // convert the int to the code number
        let code = "6110s\(cnum)"
        return getPicRefURL(code, refType: .dlRef)!
    }
    
    private func getCodeNumber(fromHref href: String) -> Int16 {
        let (_, hnum) = splitNumericEndOfString(href)
        if let hh = Int16(hnum), !hnum.isEmpty {
            return hh
        }
        return 0
    }
    
    private func runItem(withCodeNumber cnum: Int16) {
        let handler = getNextHandler()
        handler.url = getURL(fromCodeNumber: cnum)
        print("Running item \(cnum) at URL \(handler.url.absoluteString)")
        if !demo {
            handler.runInfo()
        }
    }
    
    private func runBatch() {
        for item in items[currentBatchStart..<currentBatchEnd] {
            runItem(withCodeNumber: item)
        }
    }
    
    private func nextWorkItem() {
        // an item has just been executed; advance the pointer to the next one, if any
        // advance just the item pointer within the batch window first
        nextItem()
        // count progress
        progress.completedUnitCount += 1
        if remainingBatchItemsCount == 0 {
            // if no items left in batch, reposition the batch window to the next frame, if any
            nextBatch()
            // flag that next item should be run with delay
            addDelay = true
            if remainingItemsCount > 0 {
                print("DetailsLoader queued next batch of \(remainingBatchItemsCount) with \(remainingItemsCount) left to run after \(timeInterval) secs delay. ")
            }
        } else {
            // normal batch items require no delay
            addDelay = false
            // due to nature of the operation, if we have more batch items, we have more items, so unconditionally print
            print("DetailsLoader queued next 1 of \(remainingBatchItemsCount) with \(remainingItemsCount) left. ")
        }
    }

    // ** The client calls this to begin the process of loading detail items
    // it is also called internally 
    // function will determine if more items need to be run and queue the next, or call the completion handler
    func run() {
        if moreWork {
            if demo {
                // run all the items in a synchronous loop
                while moreWork {
                    runItem(withCodeNumber: self.items[self.currentBatchStart])
                    nextWorkItem()
                }
                // call run() when done to queue the completion handler
                run()
                return
            }
            // async version (non-demo)
            // within a batch, just queue up the next one to be sent
            if addDelay {
                queue.asyncAfter(deadline: DispatchTime.now() + timeInterval) {
                    self.runBatch()
                }
            } else {
                queue.async{
                    self.runBatch()
                    // NOTE: nextWorkItem() will be run by message handler when response is received
                }
            }
        } else {
            // empty batch AND empty items: when all items have been removed, we are done
            print("DetailsLoader: no more items, running any completion handler.")
            if let completion = completion {
                self.completion = nil // don't need to keep the reference here
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
    // RUNTIME: receiver of the message response forwards the detail object to the delegate
    func messageHandler(_ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int) {
        //print("DetailsLoader received cat \(category) data \(data)")
        if let delegate = delegate {
            // pass the received item on to our delegate
            delegate.messageHandler(handler, receivedDetails: data, forCategory: category)
            //print("DetailsLoader passed cat \(category) data to delegate \(data)")
        }
        // increment the position in the queue
        nextWorkItem()
        // see if more is left to do and do it
        run()
    }
}
