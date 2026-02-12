//
//  Item.swift
//  Tenrec Terminal
//
//  Created by Iain Shigeoka on 2/11/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
