//
// Wire
// Copyright (C) 2020 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import WireSyncEngine

extension Notification.Name {
    static let UserToggledVideoInCall = Notification.Name("UserToggledVideoInCall")
}

struct CallInfo {
    var connectingDate: Date?
    var establishedDate: Date?
    var maximumCallParticipants: Int
    var toggledVideo: Bool
    let outgoing: Bool
    let video: Bool
}

private let zmLog = ZMSLog(tag: "Analytics")

final class AnalyticsCallingTracker: NSObject {

    private static let conversationIdKey = "conversationId"

    let analytics: Analytics
    var callInfos: [UUID: CallInfo] = [:]
    var callStateObserverToken: Any?
    var callParticipantObserverToken: Any?
    var screenSharingStartTimes: [String: Date] = [:]

    init(analytics: Analytics) {
        self.analytics = analytics

        super.init()

        guard let userSession = ZMUserSession.shared() else {
            zmLog.error("UserSession not available when initializing \(type(of: self))")
            return
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name.UserToggledVideoInCall, object: nil, queue: nil) { [weak self] (note) in
            if let conversationId = note.userInfo?[AnalyticsCallingTracker.conversationIdKey] as? UUID,
               var callInfo = self?.callInfos[conversationId] {
                callInfo.toggledVideo = true
                self?.callInfos[conversationId] = callInfo
            }
        }

        callStateObserverToken = WireCallCenterV3.addCallStateObserver(observer: self, userSession: userSession)
    }

    static func userToggledVideo(in voiceChannel: VoiceChannel) {
        if let conversationId = voiceChannel.conversation?.remoteIdentifier {
            NotificationCenter.default.post(name: .UserToggledVideoInCall, object: nil, userInfo: [conversationIdKey: conversationId])
        }
    }
}

// MARK: - WireCallCenterCallStateObserver

extension AnalyticsCallingTracker: WireCallCenterCallStateObserver {

    func callCenterDidChange(callState: CallState,
                             conversation: ZMConversation,
                             caller: UserType,
                             timestamp: Date?,
                             previousCallState: CallState?) {

        let conversationId = conversation.remoteIdentifier!

        switch callState {
        case .outgoing:
            let video = conversation.voiceChannel?.isVideoCall ?? false
            let callInfo = CallInfo(connectingDate: Date(), establishedDate: nil, maximumCallParticipants: 1, toggledVideo: false, outgoing: true, video: video)
            callInfos[conversationId] = callInfo
            Analytics.shared.tagEvent(.initiatedCall(asVideoCall: video, in: conversation))
        case .incoming(video: let video, shouldRing: true, degraded: _):
            let callInfo = CallInfo(connectingDate: nil, establishedDate: nil, maximumCallParticipants: 1, toggledVideo: false, outgoing: false, video: video)
            callInfos[conversationId] = callInfo
        case .answered:
            let video = conversation.voiceChannel?.isVideoCall ?? false
            if var callInfo = callInfos[conversationId] {
                callInfo.connectingDate = Date()
                Analytics.shared.tagEvent(.joinedCall(asVideoCall: video, callDirection: .incoming, in: conversation))
                callInfos[conversationId] = callInfo
            }
        case .established:
            if var callInfo = callInfos[conversationId] {
                let video = conversation.voiceChannel?.isVideoCall ?? false
                defer { callInfos[conversationId] = callInfo }
                callInfo.maximumCallParticipants = max(callInfo.maximumCallParticipants, (conversation.voiceChannel?.participants.count ?? 0) + 1)

                // .established is called every time a participant joins the call
                guard callInfo.establishedDate == nil else { return }

                callInfo.establishedDate = Date()
                Analytics.shared.tagEvent(.establishedCall(asVideoCall: video, in: conversation))
            }

            guard let userSession = ZMUserSession.shared() else {
                zmLog.error("UserSession not available when .established call")
                return
            }

            callParticipantObserverToken = WireCallCenterV3.addCallParticipantObserver(observer: self, for: conversation, userSession: userSession)
        case .terminating(let reason):
            if let callInfo = callInfos[conversationId],
               let establishedDate = callInfo.establishedDate {

                let isVideoCall = conversation.voiceChannel?.isVideoCall ?? false
                let toggleVideo = callInfo.toggledVideo
                let maximumCallParticipants = callInfo.maximumCallParticipants
                let isSharingScreen = conversation.voiceChannel?.videoState ==  .screenSharing
                let duration = -establishedDate.timeIntervalSinceNow

                Analytics.shared.tagEvent(.endedCall(asVideoCall: isVideoCall,
                                                     callDirection: .outgoing,
                                                     callDuration: duration,
                                                     callParticipants: maximumCallParticipants,
                                                     videoEnabled: toggleVideo,
                                                     screenShareEnabled: isSharingScreen,
                                                     callClosedReason: reason,
                                                     conversation: conversation))

            }
            callInfos[conversationId] = nil

            if case .inputOutputError = reason {
                presentIOErrorAlertIfAllowed()
            }

            callParticipantObserverToken = nil

        default:
            break
        }

    }

    func presentIOErrorAlertIfAllowed() {
        guard Bundle.developerModeEnabled else { return }

        let alert = UIAlertController(title: "Calling Error", message: "AVS I/O error", alertAction: .ok(style: .cancel))
        alert.presentTopmost()

    }

}

// MARK: - WireCallCenterCallParticipantObserver - tracking share screen

extension AnalyticsCallingTracker: WireCallCenterCallParticipantObserver {
    func callParticipantsDidChange(conversation: ZMConversation,
                                   participants: [CallParticipant]) {
        // record the start/end screen share timing, and tag the event when the call ends

        let selfUser = SelfUser.provider?.selfUser as? ZMUser

        // When the screen sharing starts add a record to screenSharingInfos set if no exist item with same client id exists
        if let participant = participants.first(where: { $0.state.videoState == .screenSharing }),
           screenSharingStartTimes[participant.clientId] == nil {
            screenSharingStartTimes[participant.clientId] = Date()
        } else if let screenSharedParticipant = participants.first(where: { $0.state.videoState == .stopped && ($0.user as? ZMUser != selfUser) }),
                  let screenSharingDate = screenSharingStartTimes[screenSharedParticipant.clientId] {

            // When videoState == .stopped from a remote participant, tag the event if we found a record in screenSharingInfos set with matching clientId
            Analytics.shared.tagEvent(.screenShare(callDirection: .incoming, duration: -screenSharingDate.timeIntervalSinceNow, in: conversation))

            screenSharingStartTimes[screenSharedParticipant.clientId] = nil
        }
    }
}
