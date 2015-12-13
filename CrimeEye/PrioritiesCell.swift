//
//  PrioritiesCell.swift
//  CrimeEye
//
//  Created by Gurpreet Paul on 12/12/2015.
//  Copyright © 2015 Crime Eye. All rights reserved.
//

import UIKit

class PrioritiesCell: UITableViewCell {
    
    @IBOutlet weak var date: UILabel!
    @IBOutlet weak var issue: UILabel!
    @IBOutlet weak var action: UILabel!
    

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.backgroundColor = Style.viewBackground
    }

    override func setSelected(selected: Bool, animated: Bool) {

        // Configure the view for the selected state
    }

}
