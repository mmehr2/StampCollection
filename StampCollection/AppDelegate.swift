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
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        // set up the model layer internals (persistence, backend comm, etc.)
        // first, decide which top level VC will be first to view (uses presence of particular function selector - poss.better to have a property?)
        var defaultVC: UIViewController?
        forEachTopLevelVC() { top in
            // find the one VC that will kickstart the UI (for use by init completion block)
            if top.respondsToSelector("startUI:") {
                defaultVC = top
                print("Set UI starter VC @ \(top)")
            }
        }
        
        // now initialize the data model, and trigger the UI display on its async completion
        dataModel = CollectionStore() {
            print("COLLECTION STORE INITIALIZED, READY TO GO!")
            // trigger UI here to display default VC
            if let dvc = defaultVC {
                dvc.performSelector("startUI:", withObject: self.dataModel)
            } else {
                print("Unable to start UI (no VC responds to startUI method)")
            }
        }

        // THIS CODE IS FROM RAY WENDERLICH INTERMEDIATE COREDATA TUTORIAL
        // dynamically make sure all top-level VC objects know about the data model
        forEachTopLevelVC() { top in
            // if a top level VC has a property named 'model', this will set it to the data model object we just initialized
            if top !== defaultVC && top.respondsToSelector("setModel:") {
                top.performSelector("setModel:", withObject: self.dataModel)
                print("Set one VC's model @ \(top)")
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
