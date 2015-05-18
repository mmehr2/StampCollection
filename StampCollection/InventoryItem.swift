//
//  InventoryItem.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class InventoryItem: NSManagedObject {

    @NSManaged var albumPage: String
    @NSManaged var albumRef: String
    @NSManaged var albumSection: String
    @NSManaged var albumType: String
    @NSManaged var baseItem: String
    @NSManaged var catgDisplayNum: Int16
    @NSManaged var desc: String
    @NSManaged var exOrder: Int16
    @NSManaged var itemType: String
    @NSManaged var notes: String
    @NSManaged var refItem: String
    @NSManaged var wantHave: String
    @NSManaged var category: Category
    @NSManaged var dealerItem: DealerItem
    @NSManaged var referredItem: DealerItem
    @NSManaged var page: AlbumPage

}
