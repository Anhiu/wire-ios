//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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
import UIKit
import WireDataModel

final class CollectionCellHeader: UIView {
    var message: ZMConversationMessage? {
        didSet {
            guard let message = message,
                  let serverTimestamp = message.serverTimestamp,
                  let sender = message.senderUser else {
                return
            }

            nameLabel.textColor = sender.nameAccentColor

            nameLabel.text = sender.name
            dateLabel.text = serverTimestamp.formattedDate
        }
    }

    required init(coder: NSCoder) {
        fatal("init(coder: NSCoder) is not implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(nameLabel)
        addSubview(dateLabel)

        [<#views#>].prepareForLayout()
        NSLayoutConstraint.activate([
          nameLabel.leadingAnchor.constraint(equalTo: selfView.leadingAnchor),
          nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: dateLabel.leadingAnchor),
          dateLabel.trailingAnchor.constraint(equalTo: selfView.trailingAnchor),
          nameLabel.topAnchor.constraint(equalTo: selfView.topAnchor),
          nameLabel.bottomAnchor.constraint(equalTo: selfView.bottomAnchor),
          dateLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor)
        ])
    }

    var nameLabel: UILabel = {
        let label = UILabel()
        label.accessibilityLabel = "sender name"
        label.font = .smallSemiboldFont

        return label
    }()

    var dateLabel: UILabel = {
        let label = UILabel()
        label.accessibilityLabel = "sent on"
        label.font = .smallLightFont
        label.textColor = .from(scheme: .textDimmed)

        return label
    }()
}
