package com.fintech.securecardnative

import android.app.Activity
import android.os.*
import android.view.WindowManager
import android.view.View
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

class SecureViewActivity : Activity() {

    private var startTime: Long = 0
    private var timeoutHandler: Handler? = null
    private var timeoutRunnable: Runnable? = null
    private lateinit var params: JSONObject
    private lateinit var reactContext: ReactApplicationContext
    private lateinit var config: JSONObject
    private var blurOverlay: View? = null
    private var blurOnBackground: Boolean = true
    private var isDimmed: Boolean = false

    companion object {
        var reactApplicationContext: ReactApplicationContext? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        enforceSecureFlag()
        startTime = System.currentTimeMillis()
        reactContext = reactApplicationContext!!

        val paramsJson = intent.getStringExtra("params") ?: return finish()
        params = JSONObject(paramsJson)
        config = params.getJSONObject("config")
        blurOnBackground = config.optBoolean("blurOnBackground", true)
        enforceSecureFlag()

        setupUI()
        setupTimeout()
        sendCardDataShownEvent()
    }

    private fun enforceSecureFlag() {
        getWindow()?.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    private fun setupUI() {
        val cardData = params.getJSONObject("cardData")
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

            // Reducir superficie de capturas asistidas/autofill/content capture
            importantForAutofill = View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
            if (Build.VERSION.SDK_INT >= 29) {
                importantForContentCapture = View.IMPORTANT_FOR_CONTENT_CAPTURE_NO_EXCLUDE_DESCENDANTS
            }
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

        // Campos (se muestran normales; FLAG_SECURE ya bloquea la captura)
        val panView = createField("PAN:", cardData.getString("pan"), textColor)
        val cvvView = createField("CVV:", cardData.getString("cvv"), textColor)
        val expiryView = createField("Vencimiento:", cardData.getString("expiry"), textColor)
        val holderView = createField("Titular:", cardData.getString("holder"), textColor)

        mainLayout.addView(panView)
        mainLayout.addView(cvvView)
        mainLayout.addView(expiryView)
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

    private fun createField(label: String, value: String, textColor: Int): LinearLayout {
        val fieldLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { bottomMargin = 24 }
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
        val timeout = config.optLong("timeout", 60000)
        timeoutHandler = Handler(Looper.getMainLooper())
        timeoutRunnable = Runnable { closeWithReason("TIMEOUT") }
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
        if (blurOnBackground) showBlurOverlay() else closeWithReason("BACKGROUND")
    }

    override fun onResume() {
        super.onResume()
        hideBlurOverlay()
    }

    override fun onStop() {
        super.onStop()
        if (blurOnBackground) showBlurOverlay()
    }

    override fun onStart() {
        super.onStart()
        hideBlurOverlay()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (blurOnBackground) showBlurOverlay()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (blurOnBackground) {
            if (hasFocus) hideBlurOverlay() else showBlurOverlay()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        timeoutHandler?.removeCallbacks(timeoutRunnable!!)
    }

    private fun showBlurOverlay() {
        if (blurOverlay != null) return
        val overlay = View(this)
        overlay.setBackgroundColor(Color.BLACK)
        overlay.alpha = 1.0f
        val lp = ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
        addContentView(overlay, lp)
        overlay.bringToFront()
        window.decorView.post { window.decorView.invalidate() }
        blurOverlay = overlay
        isDimmed = true
    }

    private fun hideBlurOverlay() {
        val overlay = blurOverlay
        if (overlay != null) {
            val parent = overlay.parent as? ViewGroup
            parent?.removeView(overlay)
            blurOverlay = null
        }
        isDimmed = false
    }
}
