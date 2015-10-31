//
//  InventoryItem+CoreDataProperties.swift
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

extension InventoryItem {

    @NSManaged var albumPage: String!
    @NSManaged var albumRef: String!
    @NSManaged var albumSection: String!
    @NSManaged var albumType: String!
    @NSManaged var baseItem: String!
    @NSManaged var catgDisplayNum: Int16
    @NSManaged var desc: String!
    @NSManaged var exOrder: Int16
    @NSManaged var itemType: String!
    @NSManaged var notes: String!
    @NSManaged var refItem: String!
    @NSManaged var wantHave: String!
    @NSManaged var category: Category!
    @NSManaged var dealerItem: DealerItem!
    @NSManaged var page: AlbumPage!
    @NSManaged var referredItem: DealerItem!

}
