//
//  AlbumFamily+CoreDataProperties.swift
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

extension AlbumFamily {

    @NSManaged var code: String!
    @NSManaged var descriptionX: String!
    @NSManaged var nextRef: Int16
    @NSManaged var refs: NSOrderedSet!
    @NSManaged var type: AlbumType!

}
