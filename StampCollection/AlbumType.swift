//
//  AlbumType.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class AlbumType: NSManagedObject {

    @NSManaged var code: String
    @NSManaged var ordinal: Int16
    @NSManaged var descriptionX: String
    @NSManaged var families: NSOrderedSet

}
