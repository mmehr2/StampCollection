//
//  BTItemDetailsLoader.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/21/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

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

class BTItemDetailsLoader: BTInfoProtocol {
    
    let progress: Progress
    var delegate: BTInfoProtocol?
    var completion: (() -> Void)?
    var batchSize = 10
    var timeInterval: TimeInterval = 10.0 // secs delay from when batch is emptied and starts to send again
    
    var count: Int {
        return items.count
    }
    
    private var items = Set<BTMessageDelegate>()
    private var batch = Set<BTMessageDelegate>()
    private let queue: DispatchQueue
    
    init(_ comp: (() -> Void)? = nil) {
        progress = Progress()
        // the queue operates as a serial queue, so items are requested
        queue = DispatchQueue(label: "com.azuresults.BTLoadDetailsQueue", qos: .background)
        completion = comp
    }
    
    // NOTE: this must be run on the main thread since hidden UI are created
    func addItem(withHref href: String) -> BTMessageDelegate {
        let item = BTMessageDelegate()
        item.delegate = self
        item.configToLoadItemDetailsFromWeb(href, forCategory: CATEG_SETS)
        progress.totalUnitCount += 1
        items.insert(item)
        return item
    }
    
    // NOTE: this can be run on the main queue too, or the private queue
    func run() {
        if !batch.isEmpty {
            // within a batch, just send the next one
            print("DetailsLoader queued next 1 of \(batch.count) with \(count) left. ")
            self.queue.async{
                self.batch.first!.runInfo()
            }
        } else if !items.isEmpty {
            // if we have more to go, start another batch after delay
            enqueueBatch()
        } else {
            // empty batch AND empty items: when all items have been removed, we are done
            print("DetailsLoader: no more items, running any completion handler.")
            if let completion = completion {
                self.completion = nil // don't need to keep the reference here
                DispatchQueue.main.async(execute: completion)
            }
        }
    }
    
    func enqueueBatch() {
        let N = min(items.count, batchSize)
        batch = Set(items.prefix(N))
        items = Set(items.dropFirst(N))
        print("DetailsLoader queued next batch of \(batch.count) with \(count) left to run after \(timeInterval) secs delay. ")
        queue.asyncAfter(deadline: DispatchTime.now() + timeInterval) {
            self.batch.first!.runInfo()
        }
    }

    // RUNTIME: receiver of the message response forwards the detail object to the delegate
    func messageHandler(_ handler: BTMessageDelegate, receivedDetails data: BTItemDetails, forCategory category: Int) {
        // count progress
        //print("DetailsLoader received cat \(category) data \(data)")
        progress.completedUnitCount += 1
        if let delegate = delegate {
            // pass the received item on to our delegate
            delegate.messageHandler(handler, receivedDetails: data, forCategory: category)
            //print("DetailsLoader passed cat \(category) data to delegate \(data)")
        }
        // remove this handler from current batch list
        self.batch.remove(handler)
        // see what more is left to do and do it
        self.run()
    }
}
