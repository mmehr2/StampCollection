//
//  Category+CoreDataProperties.swift
//  StampCollection
//
//  Created by Michael L Mehr on 10/6/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Category {

    @NSManaged var catalogs: String!
    @NSManaged var code: String!
    @NSManaged var exOrder: Int16
    @NSManaged var items: String!
    @NSManaged var name: String!
    @NSManaged var number: Int16
    @NSManaged var prices: String!
    @NSManaged var dealerItems: NSOrderedSet!
    @NSManaged var inventoryItems: NSOrderedSet!

}
