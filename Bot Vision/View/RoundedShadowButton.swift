//
//  RoundedShadowButton.swift
//  Bot Vision
//
//  Created by Jibran Syed on 10/28/17.
//  Copyright © 2017 Jishenaz. All rights reserved.
//

import UIKit

class RoundedShadowButton: UIButton 
{
    
    override func awakeFromNib() 
    {
        // Make a shadow
        self.layer.shadowColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        self.layer.shadowRadius = 15        // Controls blur of shadow
        self.layer.shadowOpacity = 0.75     // In percentage
        
        // Make rounded
        self.layer.cornerRadius = self.frame.height / 2
    }
    
}
