//
//  Item.swift
//  IlluminoteSceneDemo
//
//  Created by Nownes, Tobias on 5/2/25.
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
