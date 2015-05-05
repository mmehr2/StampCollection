//
//  ViewSorting.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/4/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import Foundation


 func filterArray( collection: [DealerItem], byCategory category: Int16 ) -> [DealerItem] {
    if category == CollectionStore.CategoryAll {
        return collection
    }
    return collection.filter { x in
        x.catgDisplayNum == Int16(category)
    }
}

enum SortType {
    case ByCode, ByDesc, ByPrice, ByDate
}

 func isOrderedByCode( ob1: DealerItem, ob2: DealerItem ) -> Bool {
    return true
}

 func isOrderedByDate( ob1: DealerItem, ob2: DealerItem ) -> Bool {
    let date1str = extractDateFromDesc(ob1.descriptionX)
    return true
}
