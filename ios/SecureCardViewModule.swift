import Foundation
import React
import CryptoKit
import UIKit
import CommonCrypto

@objc(SecureCardViewModule)
class SecureCardViewModule: RCTEventEmitter {
    
    private var currentSecureVC: SecureViewController?
    private let secretKey = "IO_FINTECH_SECRET_KEY_2024"
    
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
                
                if !self.validateHMACSignature(cardId: cardId, token: token, signature: signature) {
                    self.sendValidationError(code: "TOKEN_INVALID", 
                                           message: "Invalid token signature", 
                                           recoverable: false)
                    rejecter("TOKEN_INVALID", "Invalid token signature", nil)
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
    func getConstants() -> [String: Any] {
        return [
            "version": "1.0.0",
            "isAndroid": false,
            "supportsScreenshotBlocking": true,
            "supportsBiometric": true
        ]
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
    
    private func validateHMACSignature(cardId: String, token: String, signature: String) -> Bool {
        guard #available(iOS 13.0, *) else {
            return validateHMACSignatureLegacy(cardId: cardId, token: token, signature: signature)
        }
        
        let data = "\(cardId):\(token)"
        let key = SymmetricKey(data: secretKey.data(using: .utf8)!)
        let authenticationCode = HMAC<SHA256>.authenticationCode(for: data.data(using: .utf8)!, using: key)
        let computedSignature = Data(authenticationCode).map { String(format: "%02x", $0) }.joined()
        
        return computedSignature == signature
    }
    
    private func validateHMACSignatureLegacy(cardId: String, token: String, signature: String) -> Bool {
        let data = "\(cardId):\(token)"
        guard let keyData = secretKey.data(using: .utf8),
              let messageData = data.data(using: .utf8) else {
            return false
        }
        
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLength)
        defer { result.deallocate() }
        
        keyData.withUnsafeBytes { keyBytes in
            messageData.withUnsafeBytes { messageBytes in
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256),
                       keyBytes.baseAddress, keyData.count,
                       messageBytes.baseAddress, messageData.count,
                       result)
            }
        }
        
        let hmacData = Data(bytes: result, count: digestLength)
        let computedSignature = hmacData.map { String(format: "%02x", $0) }.joined()
        
        return computedSignature == signature
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
        
        // Configurar callback de cierre
        secureVC.onCloseCallback = { [weak self] closeData in
            self?.sendEvent(withName: "onSecureViewClosed", body: closeData)
            self?.currentSecureVC = nil
        }
        
        self.currentSecureVC = secureVC
        
        // Configurar observer para evento de datos mostrados
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

// MARK: - Notification Extensions

extension Notification.Name {
    static let cardDataShown = Notification.Name("CardDataShown")
    static let secureViewClosed = Notification.Name("SecureViewClosed")
}
