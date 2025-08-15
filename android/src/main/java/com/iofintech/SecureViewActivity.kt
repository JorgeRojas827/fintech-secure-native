package com.iofintech.securecardnative

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import android.widget.TextView
import android.widget.LinearLayout
import android.widget.Button
import android.graphics.Color
import android.view.Gravity
import android.view.ViewGroup
import android.util.TypedValue
import org.json.JSONObject
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.util.*

class SecureViewActivity : Activity() {
    
    private var startTime: Long = 0
    private var timeoutHandler: Handler? = null
    private var timeoutRunnable: Runnable? = null
    private lateinit var params: JSONObject
    private lateinit var reactContext: ReactApplicationContext
    
    companion object {
        var reactApplicationContext: ReactApplicationContext? = null
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        startTime = System.currentTimeMillis()
        reactContext = reactApplicationContext!!
        
        // Configuraciones de seguridad
        applySecurityFlags()
        
        // Obtener parámetros
        val paramsJson = intent.getStringExtra("params") ?: return finish()
        params = JSONObject(paramsJson)
        
        setupUI()
        setupTimeout()
        
        // Enviar evento de datos mostrados
        sendCardDataShownEvent()
    }
    
    private fun applySecurityFlags() {
        // Bloquear screenshots
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        
        // Auto-ocultar en background (blur)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED,
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
        )
    }
    
    private fun setupUI() {
        val cardData = params.getJSONObject("cardData")
        val config = params.getJSONObject("config")
        val theme = config.optString("theme", "dark")
        
        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            setPadding(48, 48, 48, 48)
            gravity = Gravity.CENTER
            setBackgroundColor(if (theme == "dark") Color.BLACK else Color.WHITE)
        }
        
        val textColor = if (theme == "dark") Color.WHITE else Color.BLACK
        
        // Título
        val titleView = TextView(this).apply {
            text = "Datos de Tarjeta"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 24f)
            setTextColor(textColor)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 32)
        }
        mainLayout.addView(titleView)
        
        // PAN
        val panView = createSecureField("PAN:", cardData.getString("pan"), textColor)
        mainLayout.addView(panView)
        
        // CVV
        val cvvView = createSecureField("CVV:", cardData.getString("cvv"), textColor)
        mainLayout.addView(cvvView)
        
        // Fecha de expiración
        val expiryView = createSecureField("Vencimiento:", cardData.getString("expiry"), textColor)
        mainLayout.addView(expiryView)
        
        // Titular
        val holderView = createSecureField("Titular:", cardData.getString("holder"), textColor)
        mainLayout.addView(holderView)
        
        // Botón cerrar
        val closeButton = Button(this).apply {
            text = "Cerrar"
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setBackgroundColor(if (theme == "dark") Color.GRAY else Color.LTGRAY)
            setTextColor(textColor)
            setPadding(32, 16, 32, 16)
            setOnClickListener { closeWithReason("USER_DISMISS") }
        }
        
        val buttonLayout = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            topMargin = 48
            gravity = Gravity.CENTER_HORIZONTAL
        }
        closeButton.layoutParams = buttonLayout
        mainLayout.addView(closeButton)
        
        setContentView(mainLayout)
    }
    
    private fun createSecureField(label: String, value: String, textColor: Int): LinearLayout {
        val fieldLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 24
            }
        }
        
        val labelView = TextView(this).apply {
            text = label
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            setTextColor(textColor)
            alpha = 0.7f
        }
        
        val valueView = TextView(this).apply {
            text = value
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTextColor(textColor)
            typeface = android.graphics.Typeface.MONOSPACE
            setPadding(0, 8, 0, 0)
        }
        
        fieldLayout.addView(labelView)
        fieldLayout.addView(valueView)
        
        return fieldLayout
    }
    
    private fun setupTimeout() {
        val config = params.getJSONObject("config")
        val timeout = config.optLong("timeout", 60000)
        
        timeoutHandler = Handler(Looper.getMainLooper())
        timeoutRunnable = Runnable {
            closeWithReason("TIMEOUT")
        }
        
        timeoutHandler?.postDelayed(timeoutRunnable!!, timeout)
    }
    
    private fun sendCardDataShownEvent() {
        val cardId = params.getString("cardId")
        val eventData = Arguments.createMap().apply {
            putString("cardId", cardId)
            putDouble("timestamp", System.currentTimeMillis().toDouble())
        }
        
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onCardDataShown", eventData)
    }
    
    private fun closeWithReason(reason: String) {
        val duration = System.currentTimeMillis() - startTime
        val cardId = params.getString("cardId")
        
        val eventData = Arguments.createMap().apply {
            putString("cardId", cardId)
            putString("reason", reason)
            putDouble("duration", duration.toDouble())
        }
        
        reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onSecureViewClosed", eventData)
        
        finish()
    }
    
    override fun onBackPressed() {
        closeWithReason("USER_DISMISS")
    }
    
    override fun onPause() {
        super.onPause()
        closeWithReason("BACKGROUND")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        timeoutHandler?.removeCallbacks(timeoutRunnable!!)
    }
}
