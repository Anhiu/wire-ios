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

import WireSyncEngine

protocol CallGridViewControllerInput {

    var floatingStream: Stream? { get }
    var streams: [Stream] { get }
    var videoState: VideoState { get }
    var networkQuality: NetworkQuality { get }
    var shouldShowActiveSpeakerFrame: Bool { get }
    var presentationMode: VideoGridPresentationMode { get }
    var callHasTwoParticipants: Bool { get }

    func isEqualTo(_ other: CallGridViewControllerInput) -> Bool
}

extension CallGridViewControllerInput where Self: Equatable {
    func isEqualTo(_ other: CallGridViewControllerInput) -> Bool {
        guard let otherState = other as? Self else { return false }
        return self == otherState
    }
    
    func asEquatable() -> AnyCallGridViewControllerInput {
        return AnyCallGridViewControllerInput(self)
    }
}

struct AnyCallGridViewControllerInput: CallGridViewControllerInput, Equatable {
    init(_ state: CallGridViewControllerInput) {
        self.value = state
    }
    
    var floatingStream: Stream? { return value.floatingStream }
    var streams: [Stream] { return value.streams }
    var videoState: VideoState { return value.videoState }
    var networkQuality: NetworkQuality { return value.networkQuality }
    var shouldShowActiveSpeakerFrame: Bool { return value.shouldShowActiveSpeakerFrame }
    var presentationMode: VideoGridPresentationMode { return value.presentationMode }
    var callHasTwoParticipants: Bool { return value.callHasTwoParticipants }

    private let value: CallGridViewControllerInput

    static func ==(lhs: AnyCallGridViewControllerInput, rhs: AnyCallGridViewControllerInput) -> Bool {
            return lhs.value.isEqualTo(rhs.value)
        }
}
