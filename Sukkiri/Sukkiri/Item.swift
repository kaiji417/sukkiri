//
//  Item.swift
//  Sukkiri
//
//  Created by 椎名魁士 on 2026/05/19.
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
