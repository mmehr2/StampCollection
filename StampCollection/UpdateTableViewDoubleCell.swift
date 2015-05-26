//
//  UpdateTableViewDoubleCell.swift
//  StampCollection
//
//  Created by Michael L Mehr on 5/25/15.
//  Copyright (c) 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

class UpdateTableViewDoubleCell: UITableViewCell {

    @IBOutlet weak var textLabelTop: UILabel!
    @IBOutlet weak var detailTextLabelTop: UILabel!
    @IBOutlet weak var textLabelBottom: UILabel!
    @IBOutlet weak var detailTextLabelBottom: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
