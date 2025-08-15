package com.fintech.securecardnative

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.turbomodule.core.interfaces.TurboModule
import com.facebook.react.modules.core.DeviceEventManagerModule
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
        private const val TAG = "SecureCard"
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
                
                withContext(Dispatchers.Main) {
                    launchSecureActivity(params, promise)
                }
            } catch (e: Exception) {
                sendValidationError("PERMISSION_DENIED", e.message ?: "Unknown error", false)
                promise.reject("OPEN_ERROR", e.message, e)
            }
        }
    }
    
    override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
        getWindow()?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    @ReactMethod
    fun closeSecureView() {
        val intent = Intent("com.fintech.CLOSE_SECURE_VIEW")
        reactContext.sendBroadcast(intent)
    }

    override fun getConstants(): Map<String, Any>? {
        val constants = mutableMapOf<String, Any>()
        constants["version"] = "1.0.0"
        constants["isAndroid"] = true
        constants["supportsScreenshotBlocking"] = true
        constants["supportsBiometric"] = true
        return constants
    }

    private fun launchSecureActivity(params: JSONObject, promise: Promise) {
        val intent = Intent(reactContext, SecureViewActivity::class.java).apply {
            putExtra("params", params.toString())
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        try {
            val activity = reactContext.currentActivity
            if (activity != null) {
                activity.startActivity(intent)
            } else {
                reactContext.startActivity(intent)
            }
            
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