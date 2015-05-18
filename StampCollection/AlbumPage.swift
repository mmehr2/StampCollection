//
//  AlbumPage.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/15/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation
import CoreData

class AlbumPage: NSManagedObject {

    @NSManaged var code: String
    @NSManaged var number: Float
    @NSManaged var section: AlbumSection
    @NSManaged var items: NSOrderedSet

}
