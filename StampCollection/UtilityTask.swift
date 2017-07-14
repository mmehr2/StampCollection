//
//  UtilityTask.swift
//  StampCollection
//
//  Created by Michael L Mehr on 7/13/17.
//  Copyright © 2017 Michael L. Mehr. All rights reserved.
//

import Foundation

// protocol defines what the class that wants to run as a task must provide
protocol UtilityTaskRunnable {
    // how to get to the proxy
    var task: UtilityTask! { get set }
    // run the task and track progress via proxy
    func run() -> String
}

// generic task, acts as a proxy for the running task, keeps track of its model, token, progress, etc.
class UtilityTask: NSObject {
    
    private var task: UtilityTaskRunnable?
    
    // create, register
    required init(forModel model_: CollectionStore, inContext token: Int,
                  withRunner runner_: UtilityTaskRunner,
                  toRun task_: UtilityTaskRunnable? = nil) {
        progress = Progress()
        task = task_
        model = model_
        contextToken = token
        super.init()
        if var task = task {
            task.task = self
        }
        progress.totalUnitCount = taskUnits
        register(with: runner_) // hooks up the progress object hierarchy also
    }
    
    var result: String = "" // keep the eventual result string just in case
    
    var taskName: String = "GENERIC TASK"
    
    var debugging = false // set to true to turn on debugging printouts
    
    var isEnabled: Bool = true  // set this if it should respond to registration and running
    
    var reportedTaskUnits: Int64 = 100
    
    var taskUnits: Int64 = 10 {
        didSet(oldValue) {
            progress.totalUnitCount = taskUnits
            reportedTaskUnits = taskUnits
        }
    }
    
    var model: CollectionStore! // TBD: make non-optional once backwards compat is removed
    var contextToken: Int
    
    var progress: Progress
    
    func runUtilityTask() -> String {
        startTask()
        // now it's safe to create our progress monitor
        result = task?.run() ?? runGeneric()
        completeTask()
        return result
    }
    
    
    func register(with: UtilityTaskRunner) {
        // register with the runner object
        with.registerUtilityTask(self as UtilityTask)
    }
    
    // generic method to test the mechanism (if task is nil / not provided)
    func runGeneric() -> String {
        // do the (fake) task here
        for step in 0...taskUnits {
            updateTask(step: step, of: taskUnits)
            sleep(1) // sec
        }
        return "\(taskName) completed."
    }
    
    func startTask() {
        if !debugging { return }
        print("Started task \(taskName) progress with 0 of pending \(taskUnits) work units.")
    }
    
    // client task can call this in middle of operation for finer grained progress; can be used to start if number of steps is known; will end task if step == of
    func updateTask(step: Int64, of: Int64 ) {
        let units = taskUnits * (step) / (of)
        progress.completedUnitCount = units
        if !debugging { return }
        let funcname = (step == 0) ? "Started" : (step == of) ? "Completed" : "Continued"
        print("\(funcname) task \(taskName) progress at step \(step) of \(of) with \(units) of pending \(taskUnits) work units.")
    }
    
    // client task must call this at end of operation to resign parent progress for thread, even if task is completed, unit-wise
    func completeTask() {
        progress.completedUnitCount = taskUnits
        if !debugging { return }
        print("Completed task \(taskName) progress with all of \(taskUnits) work units.")
    }
}
