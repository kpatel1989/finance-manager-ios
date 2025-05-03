//
//  Item.swift
//  Finance Manager
//
//  Created by Kartik Patel on 2025-05-03.
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
