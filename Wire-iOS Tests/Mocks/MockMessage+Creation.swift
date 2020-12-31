//
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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
@testable import Wire
import WireLinkPreview

final class MockMessageFactory {

    /// Create a template MockMessage with conversation, serverTimestamp, sender and activeParticipants set.
    /// When sender is not provided, create a new self user and assign as sender of the return message
    ///
    /// - Returns: a MockMessage with default values
    class func messageTemplate(sender: UserType? = nil) -> MockMessage {
        let message = MockMessage()

        let conversation = MockLoader.mockObjects(of: MockConversation.self, fromFile: "conversations-01.json")[0] as? MockConversation
        message.conversation = (conversation as Any) as? ZMConversation
        message.serverTimestamp = Date(timeIntervalSince1970: 0)
        
        if let sender = sender as? ZMUser { ///TODO: do not inject ZMUser
            message.sender = sender
            message.senderUser = sender
        } else if let sender = sender {
            message.senderUser = sender
        } else {
            let user = MockUserType.createSelfUser(name: "Tarja Turunen")
            user.accentColorValue = .strongBlue
            message.senderUser = user            
        }
        
        conversation?.activeParticipants = [message.senderUser as! MockUserType]

        return message
    }

    class func fileTransferMessage(sender: UserType? = nil) -> MockMessage? {
        let message: MockMessage? = MockMessageFactory.messageTemplate(sender: sender)

        message?.backingFileMessageData = MockFileMessageData()
        return message
    }

    class func imageMessage(sender: UserType? = nil, with image: UIImage?) -> MockMessage? {
        let imageData = MockImageMessageData()
        if let image = image, let data = image.imageData {
            imageData.mockImageData = data
            imageData.mockOriginalSize = image.size
            imageData.isDownloaded = true
        } else {
            imageData.isDownloaded = false
        }

        let message: MockMessage? = imageMessage(sender: sender)
        message?.imageMessageData = imageData

        return message
    }

    class func imageMessage(sender: UserType? = nil) -> MockMessage? {
        let message: MockMessage? = MockMessageFactory.messageTemplate(sender: sender)

        message?.imageMessageData = MockImageMessageData()

        return message
    }

    class func pendingImageMessage(sender: UserType? = nil) -> MockMessage? {
        let imageData = MockImageMessageData()

        let message: MockMessage? = imageMessage(sender: sender)
        message?.imageMessageData = imageData

        return message
    }

    class func systemMessage(with systemMessageType: ZMSystemMessageType,
                             users numUsers: Int = 0,
                             clients numClients: Int = 0,
                             sender: UserType? = nil) -> MockMessage? {
        let message = MockMessageFactory.messageTemplate(sender: sender)

        let mockSystemMessageData = MockSystemMessageData(systemMessageType: systemMessageType)

        message.serverTimestamp = Date(timeIntervalSince1970: 12345678564)


        if numUsers > 0 {
            mockSystemMessageData.users = Set(MockUser.mockUsers()[0...numUsers - 1])
        } else {
            mockSystemMessageData.users = Set()
        }

        var userClients: [AnyHashable] = []

        for user: Any in mockSystemMessageData.users {
            if let client = (user as? MockUser)?.feature(withUserClients: numClients) {
                userClients.append(contentsOf: client)
            }
        }

        mockSystemMessageData.clients = Set(userClients)

        message.backingSystemMessageData = mockSystemMessageData
        return message
    }

    class func locationMessage() -> MockMessage? {
        let message = MockMessageFactory.messageTemplate()

        message.backingLocationMessageData = MockLocationMessageData()
        return message
    }

    class func compositeMessage(sender: UserType? = nil) -> MockMessage {
        let message = MockMessageFactory.messageTemplate(sender: sender)
        return message
    }

    class func videoMessage(sender: UserType? = nil,
                            previewImage: UIImage? = nil) -> MockMessage? {
        let message: MockMessage? = fileTransferMessage(sender: sender)
        message?.backingFileMessageData.mimeType = "video/mp4"
        message?.backingFileMessageData.filename = "vacation.mp4"
        message?.backingFileMessageData.previewData = previewImage?.jpegData(compressionQuality: 0.9)
        return message
    }

    class func audioMessage(sender: UserType? = nil) -> MockMessage? {
        let message: MockMessage? = fileTransferMessage(sender: sender)
        message?.backingFileMessageData.mimeType = "audio/x-m4a"
        return message
    }

    class func textMessage(includingRichMedia shouldIncludeRichMedia: Bool) -> MockMessage? {
        return self.textMessage(withText: "Just a random text message", includingRichMedia: shouldIncludeRichMedia)
    }

    class func textMessage(withText text: String?) -> MockMessage? {
        return MockMessageFactory.textMessage(withText: text, includingRichMedia: false)
    }

    class func textMessage(withText text: String?, includingRichMedia shouldIncludeRichMedia: Bool) -> MockMessage? {
        let message = MockMessageFactory.messageTemplate()

        let textMessageData = MockTextMessageData()
        textMessageData.messageText = shouldIncludeRichMedia ? "Check this 500lb squirrel! -> https://www.youtube.com/watch?v=0so5er4X3dc" : text!
        message.backingTextMessageData = textMessageData

        return message
    }

    class func linkMessage() -> MockMessage? {
        let message = MockMessageFactory.messageTemplate()

        let textData = MockTextMessageData()
        let article = ArticleMetadata(originalURLString: "http://foo.bar/baz", permanentURLString: "http://foo.bar/baz", resolvedURLString: "http://foo.bar/baz", offset: 0)
        textData.backingLinkPreview = article
        message.backingTextMessageData = textData

        return message
    }

    class func pingMessage() -> MockMessage? {
        let message = MockMessageFactory.messageTemplate()
        message.knockMessageData = MockKnockMessageData()

        return message
    }

    class func expiredMessage(from message: MockMessage?) -> MockMessage? {
        message?.isEphemeral = true
        message?.isObfuscated = true
        message?.hasBeenDeleted = false
        return message
    }

    class func expiredImageMessage() -> MockMessage? {
        return self.expiredMessage(from: self.imageMessage())
    }

    class func expiredVideoMessage() -> MockMessage? {
        return self.expiredMessage(from: self.videoMessage())
    }

    class func expiredAudioMessage() -> MockMessage? {
        return self.expiredMessage(from: self.audioMessage())
    }

    class func expiredFileMessage() -> MockMessage? {
        return self.expiredMessage(from: self.fileTransferMessage())
    }

    class func expiredLinkMessage() -> MockMessage? {
        return self.expiredMessage(from: self.linkMessage())
    }

    class func deletedMessage(from message: MockMessage?) -> MockMessage? {
        message?.isEphemeral = false
        message?.isObfuscated = false
        message?.hasBeenDeleted = true
        return message
    }
    
    class func deletedImageMessage() -> MockMessage? {
        return self.deletedMessage(from: self.imageMessage())
    }
    
    class func deletedVideoMessage() -> MockMessage? {
        return self.deletedMessage(from: self.videoMessage())
    }
    
    class func deletedAudioMessage() -> MockMessage? {
        return self.deletedMessage(from: self.audioMessage())
    }
    
    class func deletedFileMessage() -> MockMessage? {
        return self.deletedMessage(from: self.fileTransferMessage())
    }
    
    class func deletedLinkMessage() -> MockMessage? {
        return self.deletedMessage(from: self.linkMessage())
    }
    
    class func passFileTransferMessage() -> MockMessage {
        let message = MockMessageFactory.messageTemplate()
        message.backingFileMessageData = MockPassFileMessageData()

        return message
    }

    class func audioMessage(config: ((MockMessage) -> ())?) -> MockMessage {
        let fileMessage = MockMessageFactory.fileTransferMessage()
        fileMessage?.backingFileMessageData.mimeType = "audio/x-m4a"
        fileMessage?.backingFileMessageData.filename = "sound.m4a"

        if let config = config {
            config(fileMessage!)
        }

        return fileMessage!
    }

}
