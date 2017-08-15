//
//  UtilityTaskRunner.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/13/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

/*
 DATABASE UTILITY TASK FUNCTIONS
 This is the place to add functionality to scan and fix parts of the INFO or INVENTORY databases that shouldn't need to be repeated often.
 The calls can be placed at the appropriate point in the runtime code, but can be cut off here, funneled through the master funcion.
 */

class UtilityTaskRunner: NSObject, ProgressReporting {
    
    var progress: Progress
    var model: CollectionStore
    var contextToken: Int
    
    // map of types to their functions (use nil to prevent execution)
    // NOTE: In spite of the name, the facility can be used with multiple calls and/or even running them every time. It's all in the source code here.
    // This must be dynamic so that the UI can do KVO on this object
    private dynamic var utRegistrations:[UtilityTask] = []
    
    required init(withModel model_: CollectionStore) {
        model = model_
        progress = Progress()
        // run some unit tests on the basics (supposedly quick)
        UnitTestRanges()
        // reconfigure each time called
        utRegistrations = []
        contextToken = model.getNewContextTokenForThread()
        // the base class must be initialized after we do local inits, but before we start working with them for further setup
        super.init()
        if utRegistrations.isEmpty {
            // call for all known registrations (creates progress objects with this one as parent)
            //            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self))
            //            utRegistrations[0].taskUnits = 3
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U1Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U2Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U3Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U4Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U5Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U6Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U7Task()))
            utRegistrations.append(UtilityTask(forModel: model, inContext: contextToken, withRunner: self, toRun: U8Task()))
        }
        progress.isCancellable = false // for now - might want a mechanism tho
        progress.isPausable = false // for now - might want a mechanism tho
    }
    
    func callUtilityTasks(completion: ((String)->())? = nil ) {
        var result = ""
        // filter out those who will not be running
        let tasks = utRegistrations.filter{ $0.isEnabled }
        // launch this on a background queue too
        model.addOperationToContext(contextToken) {
            // this code runs on the background thread associated with the context passed
            // parent progress must becomeCurrent() here before creating any child progress object
            for task in tasks {
                //print("Running Task \(task.taskName) synchronously on background thread.")
                // run the task (will update its own progress accordingly - needs the context token tho
                result += task.runUtilityTask()
            }
            if let completion = completion {
                // switch this back to the main thread to display the result, if any
                self.model.addCompletionOperationWithBlock() {
                    completion(result)
                }
            }
        }
    }
    
    // new way - NO PROTOCOLS since you have to be dynamic to be KVO-observable, and this requires the object to be Objective-C compatible, not pure Swift, so no protocols here
    func registerUtilityTask(_ utask: UtilityTask ) {
        //utRegistrations.append(utask) // no, this is counter-intuitive; let the original call do the append
        progress.addChild(utask.progress, withPendingUnitCount: utask.reportedTaskUnits)
        progress.totalUnitCount += utask.reportedTaskUnits
    }
    
}
