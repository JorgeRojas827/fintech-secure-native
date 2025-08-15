import UIKit
import Foundation

final class SecureMaskedLabel: UIView {
    private let hiddenView: UIView
    private let sublabel = UILabel()

    override var intrinsicContentSize: CGSize { sublabel.intrinsicContentSize }

    var text: String? {
        get { sublabel.text }
        set { sublabel.text = newValue }
    }

    var textColor: UIColor! {
        get { sublabel.textColor }
        set { sublabel.textColor = newValue }
    }

    var font: UIFont! {
        get { sublabel.font }
        set { sublabel.font = newValue }
    }

    var textAlignment: NSTextAlignment {
        get { sublabel.textAlignment }
        set { sublabel.textAlignment = newValue }
    }

    var numberOfLines: Int {
        get { sublabel.numberOfLines }
        set { sublabel.numberOfLines = newValue }
    }

    override init(frame: CGRect) {
        let tf = UITextField()
        tf.isSecureTextEntry = true
        tf.isUserInteractionEnabled = false
        tf.backgroundColor = .clear
        tf.text = " "

        if let canvas = tf.layer.sublayers?.first?.delegate as? UIView {
            canvas.subviews.forEach { $0.removeFromSuperview() }
            self.hiddenView = canvas
        } else {
            self.hiddenView = UIView()
        }

        super.init(frame: frame)

        addSubview(hiddenView)
        hiddenView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hiddenView.leftAnchor.constraint(equalTo: leftAnchor),
            hiddenView.rightAnchor.constraint(equalTo: rightAnchor),
            hiddenView.topAnchor.constraint(equalTo: topAnchor),
            hiddenView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        hiddenView.addSubview(sublabel)
        sublabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sublabel.leftAnchor.constraint(equalTo: hiddenView.leftAnchor),
            sublabel.rightAnchor.constraint(equalTo: hiddenView.rightAnchor),
            sublabel.topAnchor.constraint(equalTo: hiddenView.topAnchor),
            sublabel.bottomAnchor.constraint(equalTo: hiddenView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class SecureViewController: UIViewController {
    var cardData: [String: Any] = [:]
    var config: [String: Any] = [:]
    var onCloseCallback: (([String: Any]) -> Void)?

    private var timeoutTimer: Timer?
    private var startTime: TimeInterval = 0
    private var securityOverlay: UIView?
    
    private lazy var secureFieldBackdrop: UITextField = {
        let field = UITextField()
        field.isSecureTextEntry = true
        field.isUserInteractionEnabled = false
        field.backgroundColor = .clear
        field.alpha = 0.001
        field.text = String(repeating: " ", count: 100)
        field.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return field
    }()
    private lazy var protectedContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        container.frame = view.bounds
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return container
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        startTime = Date().timeIntervalSince1970
        setupSecurity()
        setupUI()
        setupTimeout()
        sendCardDataShownEvent()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        modalPresentationStyle = .fullScreen

        if secureFieldBackdrop.superview == nil {
            secureFieldBackdrop.frame = UIScreen.main.bounds
            view.addSubview(secureFieldBackdrop)
            view.sendSubviewToBack(secureFieldBackdrop)
        }

        if protectedContainer.superview == nil {
            protectedContainer.frame = view.bounds
            view.addSubview(protectedContainer)
            view.bringSubviewToFront(protectedContainer)
        }
    }

    private func setupSecurity() {
        let notifications: [(Notification.Name, Selector)] = [
            (UIApplication.willResignActiveNotification, #selector(showOverlay)),
            (UIApplication.didEnterBackgroundNotification, #selector(showOverlay)),
            (UIApplication.didBecomeActiveNotification, #selector(hideOverlay)),
            (UIApplication.userDidTakeScreenshotNotification, #selector(screenshotDetected))
        ]

        notifications.forEach { name, selector in
            NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
        }

        if #available(iOS 11.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(screenRecordingChanged),
                                                   name: UIScreen.capturedDidChangeNotification, object: nil)
        }

        setupSecurityOverlay()
    }

    private func setupSecurityOverlay() {
        securityOverlay = UIView(frame: view.bounds)
        securityOverlay?.backgroundColor = .black
        securityOverlay?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        securityOverlay?.isHidden = true

        let label = UILabel(frame: securityOverlay!.bounds)
        label.text = "🔒\nContenido Protegido"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .boldSystemFont(ofSize: 18)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        securityOverlay?.addSubview(label)
        protectedContainer.addSubview(securityOverlay!)
    }


    private func setupUI() {
        let isDark = (config["theme"] as? String) == "dark"
        view.backgroundColor = isDark ? .black : .white
        protectedContainer.backgroundColor = isDark ? .black : .white
        let textColor = isDark ? UIColor.white : UIColor.black

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        protectedContainer.addSubview(scrollView)

        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        let titleLabel = makeUILabel("Datos de Tarjeta", font: .boldSystemFont(ofSize: 24), color: textColor)
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let fields: [(String, String)] = [("PAN:", "pan"), ("CVV:", "cvv"), ("Vencimiento:", "expiry"), ("Titular:", "holder")]

        fields.forEach { label, key in
            if let value = cardData[key] as? String {
                stack.addArrangedSubview(makeSecureFieldRow(label: label, value: value, textColor: textColor))
            }
        }

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Cerrar", for: .normal)
        closeButton.setTitleColor(textColor, for: .normal)
        closeButton.backgroundColor = isDark ? .systemGray : .systemGray5
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: protectedContainer.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: protectedContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: protectedContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: protectedContainer.safeAreaLayoutGuide.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 32),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            closeButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 48),
            closeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 120),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            closeButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }

    private func makeUILabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeSecureFieldRow(label: String, value: String, textColor: UIColor) -> UIView {
        let container = UIView()

        let labelView = makeUILabel(label, font: .systemFont(ofSize: 14), color: textColor.withAlphaComponent(0.7))
        container.addSubview(labelView)
        labelView.translatesAutoresizingMaskIntoConstraints = false


        let valueFont: UIFont
        if #available(iOS 13.0, *) {
            valueFont = .monospacedSystemFont(ofSize: 18, weight: .regular)
        } else {
            valueFont = UIFont(name: "Menlo", size: 18) ?? .systemFont(ofSize: 18)
        }

        let secureValue = SecureMaskedLabel()
        secureValue.text = value
        secureValue.font = valueFont
        secureValue.textColor = textColor
        secureValue.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(secureValue)

        NSLayoutConstraint.activate([
            labelView.topAnchor.constraint(equalTo: container.topAnchor),
            labelView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            labelView.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            secureValue.topAnchor.constraint(equalTo: labelView.bottomAnchor, constant: 8),
            secureValue.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            secureValue.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            secureValue.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }


    private func setupTimeout() {
        let timeout = (config["timeout"] as? TimeInterval ?? 60000) / 1000.0
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.closeWithReason("TIMEOUT")
        }
    }

    private func sendCardDataShownEvent() {
        let eventData: [String: Any] = [
            "cardId": cardData["cardId"] as? String ?? "",
            "timestamp": Date().timeIntervalSince1970 * 1000
        ]
        NotificationCenter.default.post(name: Notification.Name("cardDataShown"), object: nil, userInfo: eventData)
    }


    @objc private func showOverlay() {
        securityOverlay?.isHidden = false
        if let overlay = securityOverlay {
            protectedContainer.bringSubviewToFront(overlay)
        }
    }

    @objc private func hideOverlay() {
        securityOverlay?.isHidden = true
    }

    @objc private func screenshotDetected() {
        closeWithReason("SCREENSHOT_ATTEMPT")
    }

    @objc private func screenRecordingChanged() {
        if #available(iOS 11.0, *), UIScreen.main.isCaptured {
            closeWithReason("SCREEN_RECORDING_DETECTED")
        }
    }

    @objc private func closeButtonTapped() {
        closeWithReason("USER_DISMISS")
    }

    func closeWithReason(_ reason: String) {
        let closeData: [String: Any] = [
            "cardId": cardData["cardId"] as? String ?? "",
            "reason": reason,
            "duration": (Date().timeIntervalSince1970 - startTime) * 1000
        ]

        onCloseCallback?(closeData)
        NotificationCenter.default.post(name: Notification.Name("secureViewClosed"), object: nil, userInfo: closeData)

        timeoutTimer?.invalidate()
        dismiss(animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timeoutTimer?.invalidate()
    }
}