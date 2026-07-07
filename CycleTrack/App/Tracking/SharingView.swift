//
//  SharingView.swift
//  CycleTrack
//
//  Created by Andreas Arendt on 07.07.26.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SharingView: View {
    
    var body: some View {
        
        HStack {
            let linkAction = TrackingAction(title: "Link", systemImage: "link.circle")
            CycleTrackActionButton(action: linkAction) { }

            let cycleTrackAction = TrackingAction(title: "Cycle Track", systemImage: "figure.outdoor.cycle")
            CycleTrackActionButton(action: cycleTrackAction) { }

            let whatsappAction = TrackingAction(title: "WhatsApp", resourceImage: "whatsapp")
            CycleTrackActionButton(action: whatsappAction) { }
            
        }
    }
}

#Preview {
    SharingView()
}
