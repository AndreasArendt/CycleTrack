//
//  Watcher.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 06.07.26.
//

import SwiftUI

@Observable
class Watcher : Identifiable {
    var id: UUID
    var name: String
    var isActive: Bool
    var image: ImageResource?
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.isActive = false
        self.image = nil
    }
}
