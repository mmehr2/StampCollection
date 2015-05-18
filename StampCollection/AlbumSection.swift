//
//  AlbumSection.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class AlbumSection: NSManagedObject {

    @NSManaged var code: String
    @NSManaged var descriptionX: String
    @NSManaged var ordinal: Int16
    @NSManaged var ref: AlbumRef
    @NSManaged var pages: NSOrderedSet

}
