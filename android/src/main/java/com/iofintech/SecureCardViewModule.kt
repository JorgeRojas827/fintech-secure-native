package com.iofintech.securecardnative

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import kotlinx.coroutines.*
import org.json.JSONObject
import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.text.SimpleDateFormat
import java.util.*

@ReactModule(name = SecureCardViewModule.NAME)
class SecureCardViewModule(private val reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext), TurboModule {

    companion object {
        const val NAME = "SecureCardViewModule"
        private const val TAG = "SecureCardView"
        private var SECRET_KEY = "SECURE_CARD_VIEW_SECRET_KEY_2024"
        
        fun setSecretKey(secretKey: String) {
            SECRET_KEY = secretKey
        }
    }

    init {
        SecureViewActivity.reactApplicationContext = reactContext
    }

    override fun getName() = NAME

    @ReactMethod
    fun openSecureView(paramsJson: String, promise: Promise) {
        MainScope().launch {
            try {
                val params = JSONObject(paramsJson)
                val cardId = params.getString("cardId")
                val token = params.getString("token")
                val signature = params.getString("signature")
                
                if (isTokenExpired(token)) {
                    sendValidationError("TOKEN_EXPIRED", "Token has expired", true)
                    promise.reject("TOKEN_EXPIRED", "Token has expired")
                    return@launch
                }
                
                if (!validateHMACSignature(cardId, token, signature)) {
                    sendValidationError("TOKEN_INVALID", "Invalid token signature", false)
                    promise.reject("TOKEN_INVALID", "Invalid token signature")
                    return@launch
                }
                
                withContext(Dispatchers.Main) {
                    launchSecureActivity(params, promise)
                }
            } catch (e: Exception) {
                sendValidationError("PERMISSION_DENIED", e.message ?: "Unknown error", false)
                promise.reject("OPEN_ERROR", e.message, e)
            }
        }
    }

    @ReactMethod
    fun closeSecureView() {
        val intent = Intent("com.iofintech.CLOSE_SECURE_VIEW")
        reactContext.sendBroadcast(intent)
    }

    @ReactMethod
    fun getConstants(): WritableMap {
        val constants = Arguments.createMap()
        constants.putString("version", "1.0.0")
        constants.putBoolean("isAndroid", true)
        constants.putBoolean("supportsScreenshotBlocking", true)
        constants.putBoolean("supportsBiometric", true)
        return constants
    }

    private fun isTokenExpired(token: String): Boolean {
        return try {
            val parts = token.split(":")
            if (parts.size < 2) return true
            
            val timestamp = parts[1].toLong()
            val currentTime = System.currentTimeMillis()
            val tokenAge = currentTime - timestamp
            
            tokenAge > 3600000
        } catch (e: Exception) {
            true
        }
    }

    private fun validateHMACSignature(cardId: String, token: String, signature: String): Boolean {
        return try {
            val mac = Mac.getInstance("HmacSHA256")
            val secretKey = SecretKeySpec(SECRET_KEY.toByteArray(), "HmacSHA256")
            mac.init(secretKey)
            
            val data = "$cardId:$token"
            val computedSignature = mac.doFinal(data.toByteArray())
                .joinToString("") { "%02x".format(it) }
            
            computedSignature == signature
        } catch (e: Exception) {
            false
        }
    }

    private fun launchSecureActivity(params: JSONObject, promise: Promise) {
        val intent = Intent(reactContext, SecureViewActivity::class.java).apply {
            putExtra("params", params.toString())
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        try {
            currentActivity?.startActivity(intent) ?: reactContext.startActivity(intent)
            
            sendEvent("onSecureViewOpened", Arguments.createMap().apply {
                putString("cardId", params.getString("cardId"))
                putDouble("timestamp", System.currentTimeMillis().toDouble())
            })
            
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("LAUNCH_ERROR", "Failed to launch secure view", e)
        }
    }

    private fun sendValidationError(code: String, message: String, recoverable: Boolean) {
        sendEvent("onValidationError", Arguments.createMap().apply {
            putString("code", code)
            putString("message", message)
            putBoolean("recoverable", recoverable)
        })
    }

    private fun sendEvent(eventName: String, params: WritableMap) {
        reactContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }
}