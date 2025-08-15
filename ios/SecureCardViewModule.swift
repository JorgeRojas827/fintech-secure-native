import Foundation
import React
import CryptoKit
import UIKit
import CommonCrypto

@objc(SecureCardViewModule)
class SecureCardViewModule: RCTEventEmitter {
    
    private var currentSecureVC: SecureViewController?
    private let secretKey = "SECURE_CARD_VIEW_SECRET_KEY_2024"
    
    override init() {
        super.init()
    }
    
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    override func supportedEvents() -> [String]! {
        return [
            "onSecureViewOpened",
            "onValidationError", 
            "onCardDataShown",
            "onSecureViewClosed"
        ]
    }
    
    @objc
    func openSecureView(_ paramsJson: String, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            do {
                guard let data = paramsJson.data(using: .utf8),
                      let params = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                    rejecter("PARSE_ERROR", "Invalid parameters", nil)
                    return
                }
                
                guard let cardId = params["cardId"] as? String,
                      let token = params["token"] as? String,
                      let signature = params["signature"] as? String else {
                    rejecter("MISSING_PARAMS", "Missing required parameters", nil)
                    return
                }
                
                if self.isTokenExpired(token) {
                    self.sendValidationError(code: "TOKEN_EXPIRED", 
                                           message: "Token has expired", 
                                           recoverable: true)
                    rejecter("TOKEN_EXPIRED", "Token has expired", nil)
                    return
                }
              
                self.processSecureView(params: params, resolver: resolver, rejecter: rejecter)
                
            } catch {
                rejecter("PARSE_ERROR", "Invalid JSON parameters", error)
            }
        }
    }
    
    @objc
    func closeSecureView() {
        DispatchQueue.main.async { [weak self] in
            self?.currentSecureVC?.closeWithReason("USER_DISMISS")
            self?.currentSecureVC = nil
        }
    }
    
    @objc
    func getConstants(_ resolve: RCTPromiseResolveBlock, rejecter reject: RCTPromiseRejectBlock) {
        let constants: [String: Any] = [
            "version": "1.0.0",
            "isAndroid": false,
            "supportsScreenshotBlocking": true,
            "supportsBiometric": true
        ]
        resolve(constants)
    }
    

    
    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.components(separatedBy: ":")
        guard parts.count >= 2,
              let timestamp = Double(parts[1]) else {
            return true
        }
        
        let currentTime = Date().timeIntervalSince1970 * 1000
        let tokenAge = currentTime - timestamp
        
        return tokenAge > 3600000
    }
    
    private func processSecureView(params: [String: Any], resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        guard let cardId = params["cardId"] as? String,
              let cardData = params["cardData"] as? [String: Any] else {
            rejecter("INVALID_PARAMS", "Invalid card data", nil)
            return
        }
        
        let config = params["config"] as? [String: Any] ?? [:]
        
        let secureVC = SecureViewController()
        secureVC.cardData = cardData
        secureVC.config = config
        
        secureVC.onCloseCallback = { [weak self] closeData in
            self?.sendEvent(withName: "onSecureViewClosed", body: closeData)
            self?.currentSecureVC = nil
        }
        
        self.currentSecureVC = secureVC
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCardDataShown(_:)),
            name: .cardDataShown,
            object: nil
        )
        
        guard let rootVC = RCTPresentedViewController() else {
            rejecter("NO_ROOT_VC", "No root view controller available", nil)
            return
        }
        
        rootVC.present(secureVC, animated: true) { [weak self] in
            let eventData: [String: Any] = [
                "cardId": cardId,
                "timestamp": Date().timeIntervalSince1970 * 1000
            ]
            self?.sendEvent(withName: "onSecureViewOpened", body: eventData)
            resolver(nil)
        }
    }
    
    @objc private func handleCardDataShown(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            sendEvent(withName: "onCardDataShown", body: userInfo)
        }
    }
    
    private func sendValidationError(code: String, message: String, recoverable: Bool) {
        let errorData: [String: Any] = [
            "code": code,
            "message": message,
            "recoverable": recoverable
        ]
        sendEvent(withName: "onValidationError", body: errorData)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let cardDataShown = Notification.Name("cardDataShown")
    static let secureViewClosed = Notification.Name("secureViewClosed")
}
