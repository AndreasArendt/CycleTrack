//
//  Watcher.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 06.07.26.
//

import SwiftUI

@Observable
class Watcher : Identifiable {
    var id: String
    var name: String
    var isActive: Bool
    var invitationId: String?
    var image: ImageResource?
    
    init(id: String = UUID().uuidString, name: String, isActive: Bool = false, invitationId: String? = nil) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.invitationId = invitationId
        self.image = nil
    }
}
