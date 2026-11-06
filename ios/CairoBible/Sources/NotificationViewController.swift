import UIKit
import UserNotifications
import UserNotificationsUI

final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    let titleLabel = UILabel()
    let bodyLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        bodyLabel.font = .preferredFont(forTextStyle: .body)
        bodyLabel.adjustsFontForContentSizeCategory = true
        bodyLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12)
        ])
    }

    func didReceive(_ notification: UNNotification) {
        let content = notification.request.content
        configure(
            title: content.title,
            body: content.body,
            isRightToLeft: content.userInfo["translation"] as? String == "svd"
        )
    }

    func configure(title: String, body: String, isRightToLeft: Bool) {
        titleLabel.text = title
        bodyLabel.text = body
        let direction: UISemanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
        let alignment: NSTextAlignment = isRightToLeft ? .right : .left
        view.semanticContentAttribute = direction
        titleLabel.semanticContentAttribute = direction
        bodyLabel.semanticContentAttribute = direction
        titleLabel.textAlignment = alignment
        bodyLabel.textAlignment = alignment
    }
}
