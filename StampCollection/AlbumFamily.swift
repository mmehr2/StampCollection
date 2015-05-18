//
//  AlbumFamily.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class AlbumFamily: NSManagedObject {

    @NSManaged var code: String
    @NSManaged var descriptionX: String
    @NSManaged var nextRef: Int16
    @NSManaged var type: AlbumType
    @NSManaged var refs: NSOrderedSet

}
