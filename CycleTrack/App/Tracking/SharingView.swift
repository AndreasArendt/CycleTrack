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
    @Environment(\.openURL) private var openURL

    let activityId: String?
    private let activityRepository = ActivityRepository()
    @State private var invitationToken: String?
    @State private var isCreatingInvitation = false
    @State private var statusText: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let activityId {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invitation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(invitationToken ?? activityId)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if let statusText {
                        Text(statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("Start live tracking to create an activity link.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack {
                let linkAction = TrackingAction(title: "Link", systemImage: "link.circle")
                CycleTrackActionButton(action: linkAction) {
                    copyShareText()
                }

                let cycleTrackAction = TrackingAction(title: "Cycle Track", systemImage: "figure.outdoor.cycle")
                CycleTrackActionButton(action: cycleTrackAction) {
                    copyActivityId()
                }

                let whatsappAction = TrackingAction(title: "WhatsApp", resourceImage: "whatsapp")
                CycleTrackActionButton(action: whatsappAction) {
                    openWhatsApp()
                }
            }
        }
        .onAppear {
            createInvitationIfNeeded()
        }
        .onChange(of: activityId) {
            invitationToken = nil
            statusText = nil
            createInvitationIfNeeded()
        }
    }

    private var shareText: String? {
        guard let invitationToken else { return nil }

        return "Follow my CycleTrack live activity: \(invitationToken)"
    }

    private func copyShareText() {
        createInvitationIfNeeded {
            guard let shareText else { return }

            #if canImport(UIKit)
            UIPasteboard.general.string = shareText
            #endif
        }
    }

    private func copyActivityId() {
        createInvitationIfNeeded {
            guard let invitationToken else { return }

            #if canImport(UIKit)
            UIPasteboard.general.string = invitationToken
            #endif
        }
    }

    private func openWhatsApp() {
        createInvitationIfNeeded {
            guard let shareText,
                  let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "whatsapp://send?text=\(encodedText)")
            else { return }

            openURL(url)
        }
    }

    private func createInvitationIfNeeded(completion: (() -> Void)? = nil) {
        guard invitationToken == nil, !isCreatingInvitation, let activityId else {
            completion?()
            return
        }

        isCreatingInvitation = true
        statusText = "Creating invite..."

        activityRepository.createInvitation(activityId: activityId) { result in
            DispatchQueue.main.async {
                isCreatingInvitation = false

                switch result {
                case .success(let token):
                    invitationToken = token
                    statusText = "Share this invite token."
                case .failure(let error):
                    statusText = "Invite failed: \(error.localizedDescription)"
                }

                completion?()
            }
        }
    }
}

#Preview {
    SharingView(activityId: "preview-activity")
}
