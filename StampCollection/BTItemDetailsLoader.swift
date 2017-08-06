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

/*
 Design Update (not Architecture):
 The entire design of the BTMessageDelegate subsystem has been called into question and found wanting.
 Using hidden WKWebViews with script injection, a novel technique I designed, is not considered standard practice. Specifically, it seems it cannot be used to fully automate updates from a background task as I have attempted to do here. It is a much better design to download the webpage text as a normal data task in a URLSession, and then parse it with a library such as SwiftSoup that can parse HTML into a parse tree like what Javascript would do to create the DOM.
 I can redesign the details loader to use this method more simply because it uses minimal Javascript and simple parsing on the body text. It currently finds line 4 of the body text. I can possibly even put something together without using the library (and CocoaPods) at all.
 Later on, I can work this library into the BTMessageDelegate class, replacing the three JS files and message generation design with a Swift-based parsing module that can use a delegate setup to retain much of its existing design. Then I can fully background-automate the ReloadAll function of the BT (and JS) categories VC. This may take some time to get right, and I need to figure out the best testing for it (will using Update with no changes triggered be sufficient proof?).
 
 UPDATE:
 I will use the BTMessageDelegate as a holder for the URL, not actively use it to load the URL. This will allow the dealer store to extract the code from the URL and route the BTItemDetails to the proper BTDealerItem. I could change the BTInfoProtocol instead, and may do so after converting the entire download process, but for now, this is sufficient.
 I use an internal (ephemeral) URLSession to dispatch URLSessionDataTasks. I chose ephemeral because the extra features are probably not needed in the default session, but if I am mistaken, a .default configuration should be fine. Eventually, we will want .background to be used for the dealer store's overall download task (ReloadAll).
 To keep the data tasks from being deleted during processing, their references are kept in an internal table indexed by code number. When the completion handler is run, it will remove the internal reference and release the object memory.
 The task completion handler (since we are not using any delegates) must deal with parsing the data, which comes in as raw HTML. For purposes of this project, the fixed format HTML has title and detail lines in known locations in the lines array (lines 32 and 38), and as long as BT doesn't change this format, we can parse the info we need by stripping HTML tags from the returned text. When we have a full HTML parsing library on board, this can be replaced to get the proper structure (which also is at the BT site's whim to change if they have a need).
 Once the data is parsed and a BTItemDetails object is created, we can simulate the receipt of the BTMessageDelegate's BTInfoProtocol message, which will send the item and its chosen BTMD handler to the recipient (dealer store).
 
 TBD - we can stop the page loading (for now) once 38 lines have been received. This will require use of the delegates to the data task, but may significantly shorten the time needed overall, especially when having to download the images, and the long text of the leaflet that is included after the summary line we want.
 */

class BTItemDetailsLoader: BTInfoProtocol {

    var demo: Bool = false
    private(set) var progress: Progress
    var delegate: BTInfoProtocol?
    var completion: (() -> Void)?
    var batchSize = 25
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
    
    private typealias ItemCollection = Array<Int16>
    private var items = ItemCollection()
    private var currentBatchStart: ItemCollection.Index
    private var currentBatchEnd: ItemCollection.Index
    private var initialBatchSize = 0
    
    private var session: URLSession!
    private var activeTasks: [Int16:URLSessionDataTask] = [:] // hashed by internal code number
    private var cancelling = false
    
    private func firstItem() {
        currentBatchStart = items.startIndex
        currentBatchEnd = currentBatchStart
        nextBatch()
    }
    
    private func setLastItem() {
        currentBatchStart = items.endIndex
        currentBatchEnd = currentBatchStart
    }
    
    private func nextItem() {
        currentBatchStart = items.index(after: currentBatchStart)
    }
    
    private func nextBatch() {
        if let cbe = items.index(currentBatchEnd, offsetBy: batchSize, limitedBy: items.endIndex) {
            currentBatchEnd = cbe
        } else {
            currentBatchEnd = items.endIndex
        }
        initialBatchSize = remainingBatchItemsCount
    }
    
    init(_ comp: (() -> Void)? = nil) {
        progress = Progress()
        completion = comp
        currentBatchStart = items.startIndex
        currentBatchEnd = currentBatchStart
        // initial index is array start
        currentHandler = handlers.startIndex
        // set up the pool of handler objects: configure each to talk back to us for details usage
        // NOTE: this object must be created on the main thread; else there must be a configure() function to do this
        configureHandlers()
        // configure the session object here? no, wait until runtime
        // set up the window (for empty array) so that we can always call run()
        firstItem()
    }
    
    private func configureHandlers() {
        // create a pool of batchSize length containing handlers of class BTMessageDelegate
        print("Configuring pool of \(batchSize) message delegates")
        for _ in 0..<batchSize {
            let handler = BTMessageDelegate()
            // UPDATE: now we are only using the handler as a holder for the URL instead of an active object
            // Note that the URL will be supplied later at run() time
            handler.categoryNumber = Int(CATEG_SETS)
            handlers.append(handler)
        }
    }
    
    private func configureSession() {
        // adding a URLSession to convert over to using data tasks instead of script injection
        // in case of cancellation, or first time after init(), the ref will be nil and we can create a new session
        guard session == nil else { return }
        print("Created new URL session in ephemeral configuration.")
        session = URLSession(configuration: .ephemeral)
    }
    
    private func getNextHandler() -> BTMessageDelegate {
        // result is current handler
        let result = handlers[currentHandler]
        //let hd = currentHandler - handlers.startIndex
        //print("Assigning handler #\(hd+1)")
        // bump current handler pointer (implements round-robin dispatcher for handler pool)
        currentHandler = handlers.index(currentHandler, offsetBy: 1)
        if currentHandler == handlers.endIndex {
            currentHandler = handlers.startIndex
        }
        return result
    }

    // ** The client calls this to reset the internal data prior to calling addItem() to accumulate items to run
    func clear() {
        items = []
        firstItem()
        progress = Progress()
    }

    // ** The client calls this to add a new item href to the list of details to load
    func addItem(withHref href: String) -> Bool {
        var added = false
        let codeNum = getCodeNumber(fromHref: href)
        let filterPolicy = !(codeNum > 0) // set to T to ignore all but exceptional items for testing
        var process = true
        if filterPolicy {
            process = BTItemDetails.isExceptional(codeNumber: codeNum)
        }
        if process  {
            items.append(codeNum)
            progress.totalUnitCount += 1
            // update initial window so we are always ready to have run() called
            firstItem()
            added = true
        }
        return added
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
            // create a data task
            let dataTask = session.dataTask(with: handler.url) { data, response, error in
                // this closure will run when a response is received by the task
                if let error = error {
                    // accumulate error message
                    print("DataTask for \(handler.url.absoluteString) got client-side error: \(error.localizedDescription)\n")
                } else if let data = data,
                    let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    // parse the response HTML that is in the data buffer
                    let html = String(data: data, encoding: .ascii)
                    // generate a BTItemDetails from lines 2 and 4 of the body text
                    let lastLineOfInterest = 37 // as in HTML lines, not text lines, numbered from 0 (View Page Source numbers from 1)
                    if let hlines = html?.components(separatedBy: "\n"),
                        hlines.count > lastLineOfInterest {
                        // this seems to always be on lines 32 and 38 of the HTML as currently formatted by the BT site
                        // NOTE: VERY KLUDGEY, BUT we can get away without an HTML parsing library for now
                        let titleLineRaw = hlines[lastLineOfInterest - 6]
                        let detailLineRaw = hlines[lastLineOfInterest]
                        let titleLine = stripCRs(stripTags(titleLineRaw))
                        let detailLine = stripCRs(stripTags(detailLineRaw))
                        //print("Found title line 6110s\(cnum): raw=[\(titleLineRaw)], stripped=[\(titleLine)]")
                        //print("Found info line 6110s\(cnum): raw=[\(detailLineRaw)], stripped=[\(detailLine)]")
                        let details = BTItemDetails(titleLine: titleLine, infoLine: detailLine, codeNum: cnum)
                        // simulate the BTInfoProtocol message from the BTMessageDelegate supplied here
                        self.messageHandler(handler, receivedDetails: details, forCategory: Int(CATEG_SETS))
                    } else {
                        print("DataTask for \(handler.url.absoluteString) received less than 38 lines of HTML data.")
                    }
                } else {
                    print("DataTask for \(handler.url.absoluteString) received null data or response, or code other than 200.")
                }
                // in all cases, remove the saved task from the reference list
                self.activeTasks[cnum] = nil
                if self.cancelling {
                    // during cancellation, we just let the tasks delete themselves
                    // when the active task map is empty, we are done cancelling
                    if self.activeTasks.isEmpty {
                        // okay to finally finish the cancellation process and run the UI completion handler
                        // now that we have saved our state, we can run the completion handler
                        self.setLastItem() // places pointers at end so moreWork will return false and run() will call the completion handler
                        self.cancelling = false // run() will only do the completion if not cancelling
                        self.run()
                        // and then we can put the pointers back to the beginning
                        self.firstItem()
                        // now it's okay to allow the user to call run() again to "resume" where we left off
                        print("Cancellation of active tasks complete.")
                   }
                } else {
                    // increment the position in the queue for every item
                    // NOTE: items will possibly finish out of order, but we only need to make sure we count each one
                    self.nextWorkItem()
                    // see if more is left to do and do it
                    self.run()
                }
            }
            // save the data task object ref so it won't crash while loading
            activeTasks[cnum] = dataTask
            // resume the data task so it will run
            dataTask.resume()
        }
    }
    
    private func runBatch() {
        for item in items[currentBatchStart..<currentBatchEnd] {
            runItem(withCodeNumber: item)
        }
    }
    
    private func nextWorkItem() {
        // an item has just been executed; advance the pointer to the next one, if any
        //print("Pointers at start of nextWorkItem(): CBS=\(currentBatchStart). CBE=\(currentBatchEnd), IBS=\(initialBatchSize)")
        // advance just the item pointer within the batch window first
        nextItem()
        // count progress
        progress.completedUnitCount += 1
        if remainingBatchItemsCount == 0 {
            // if no items left in batch, reposition the batch window to the next frame, if any
            nextBatch()
//            if remainingItemsCount > 0 {
//                print("DetailsLoader queued next batch of \(remainingBatchItemsCount) with \(remainingItemsCount) left to run after \(timeInterval) secs delay. ")
//            }
        } else {
            // due to nature of the operation, if we have more batch items, we have more items, so unconditionally print
            //print("DetailsLoader queued next 1 of \(remainingBatchItemsCount) with \(remainingItemsCount) left. ")
        }
        //print("Pointers at end of nextWorkItem(): CBS=\(currentBatchStart). CBE=\(currentBatchEnd), IBS=\(initialBatchSize)")
    }

    // ** The client calls this to begin the process of loading detail items
    // it is also called internally 
    // function will determine if more items need to be run and queue the next, or call the completion handler
    func run() {
        if moreWork && !cancelling {
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
            configureSession()
            // At this point, nextWorkItem() has either just updated the batch size for the next batch
            // OR, it has counted one of the items of the current batch and the count is smaller but nonzero
            if remainingBatchItemsCount == initialBatchSize {
                runBatch()
                // NOTE: nextWorkItem() will be run by message handler when response is received
            }
        } else if !cancelling {
            // empty batch AND empty items: when all items have been removed, we are done
            // release the session object
            session = nil
            //print("DetailsLoader: no more items, running any completion handler.")
            if let completion = completion {
                self.completion = nil // don't need to keep the reference here
                DispatchQueue.main.async(execute: completion)
            }
        }
    }

    // cancel remaining active tasks and run the completion handler
    // we can also reinitialize the items[] list in case client wants to call run() again to restart later
    func cancel() {
        // make sure we are running
        if session == nil || cancelling {
            print("Detail loader ignored canecallation request while cancelling or not running.")
            return
        }
        // prevent active threads from retriggering new calls
        cancelling = true
        print("Starting cancellation of active tasks...")
        // now that we are using tasks, we can cancel them
        session.invalidateAndCancel()
        // PROBLEM: session is now useless and cannot be reused next time; we need to replace to rerun
        session = nil
        // PROBLEM2: the cancellation requires some time as all active threads finish running and give cancelled errors
        //   We can let the regular mechanism empty the activeTasks array as usual
        //   When it is finally empty, the cancellation is complete
        //   However, all the items that haven't completed need to be saved for later restart
        // We can generate a new items array from these few numbers and the remaining uncompleted batches
        let resumeInfo1 = Array(activeTasks.keys).sorted()
        let resumeInfo = items[currentBatchEnd..<items.endIndex]
        items = resumeInfo1 + resumeInfo
        // NOTE: the cancellation process continues until all the active tasks have errored out
    }
    
    // RUNTIME: receiver of the message response forwards the detail object to the delegate
    func messageHandler(_ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int) {
        //print("DetailsLoader received cat \(category) data \(data)")
        if let delegate = delegate {
            // pass the received item on to our delegate
            delegate.messageHandler(handler, receivedDetails: data, forCategory: category)
            //print("DetailsLoader passed cat \(category) data to delegate \(data)")
        }
    }
}
