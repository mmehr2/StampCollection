//
//  AppDelegate.swift
//  StampCollection
//
//  Created by Michael L Mehr on 4/9/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    var dataModel: CollectionStore?
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.azuresults.StampCollection" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
        }()

    private func forEachTopLevelVC(block: (UIViewController) -> Void) {
        if let tab = window?.rootViewController as? UITabBarController {
            for child in tab.viewControllers ?? [] {
                if let child = child as? UINavigationController, top = child.topViewController {
                    block(top)
                }
            }
        }
    }

    /// restartUI - function to update all top level user interfaces once the CollectionStore has been (re-)initialized
    ///
    /// It will send the startUI(:) selector to all top-level VC's (those directly attached to the NavigationControllers under the master TabBarController
    /// It will pass a reference to the data model object (CollectionStore) for access to the refreshed CoreData objects.
    func restartUI() {
        // trigger UI here on VCs that depend on model data
        forEachTopLevelVC() { top in
            // find the one VC that will kickstart the UI (for use by init completion block)
            if top.respondsToSelector("startUI:") {
                top.performSelector("startUI:", withObject: self.dataModel)
                print("Started UI for VC @ \(top)")
            }
        }
    }
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        // set up the model layer internals (persistence, backend comm, etc.)
        // trigger the UI display on its async completion
        dataModel = CollectionStore() {
            print("Collection Store initialization completed.")
            self.restartUI()
        }
        
        // THIS CODE IS FROM RAY WENDERLICH INTERMEDIATE COREDATA TUTORIAL
        // dynamically make sure all top-level VC objects know about the data model
        forEachTopLevelVC() { top in
            // if a top level VC has a property named 'model', this will set it to the data model object we just initialized
            if top.respondsToSelector("setModel:") {
                top.performSelector("setModel:", withObject: self.dataModel)
                print("Set VC's model @ \(top)")
            }
        }
        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        dataModel?.saveMainContext()
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        dataModel?.saveMainContext()
    }
    
    
}
