//
//  ItemTableViewCell.swift
//  StampCollection
//
//  Created by Michael L Mehr on 6/21/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class ItemTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
}
