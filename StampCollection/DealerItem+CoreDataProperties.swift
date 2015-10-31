//
//  DealerItem+CoreDataProperties.swift
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

extension DealerItem {

    @NSManaged var buy1: String!
    @NSManaged var buy2: String!
    @NSManaged var buy3: String!
    @NSManaged var buy4: String!
    @NSManaged var cat1: String!
    @NSManaged var cat2: String!
    @NSManaged var catgDisplayNum: Int16
    @NSManaged var descriptionX: String!
    @NSManaged var exOrder: Int16
    @NSManaged var group: String!
    @NSManaged var id: String!
    @NSManaged var oldprice1: String!
    @NSManaged var oldprice2: String!
    @NSManaged var oldprice3: String!
    @NSManaged var oldprice4: String!
    @NSManaged var pictid: String!
    @NSManaged var pictype: String!
    @NSManaged var price1: String!
    @NSManaged var price2: String!
    @NSManaged var price3: String!
    @NSManaged var price4: String!
    @NSManaged var status: String!
    @NSManaged var category: Category!
    @NSManaged var inventoryItems: NSOrderedSet!
    @NSManaged var referringItems: NSOrderedSet!

}
