package com.example.max.max.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.graphics.PixelFormat
import android.view.View
import android.view.WindowManager
import kotlin.math.sin

class MaxBorderAnimService : Service() {

    companion object {
        // Mode constants sent via Intent
        const val ACTION_START     = "START_BORDER"
        const val ACTION_STOP      = "STOP_BORDER"
        const val EXTRA_MODE       = "border_mode"
        const val MODE_USER        = "user"   // blue
        const val MODE_MAX         = "max"    // red
        const val MODE_IDLE        = "idle"   // hidden

        private var instance: MaxBorderAnimService? = null

        fun updateMode(mode: String) {
            instance?.setMode(mode)
        }
    }

    private lateinit var windowManager: WindowManager
    private var borderView: BorderWaveView? = null
    private var currentMode: String = MODE_IDLE

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        addBorderOverlay()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        val mode   = intent?.getStringExtra(EXTRA_MODE) ?: MODE_IDLE

        when (action) {
            ACTION_STOP -> {
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START -> setMode(mode)
        }
        return START_STICKY
    }

    private fun setMode(mode: String) {
        currentMode = mode
        borderView?.setMode(mode)
    }

    private fun addBorderOverlay() {
        val display = windowManager.defaultDisplay
        val metrics = android.util.DisplayMetrics()
        display.getRealMetrics(metrics)
        val w = metrics.widthPixels
        val h = metrics.heightPixels

        val layerType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            w, h,
            layerType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        )

        borderView = BorderWaveView(this).also { view ->
            view.setMode(currentMode)
            windowManager.addView(view, params)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        borderView?.stopAnimation()
        borderView?.let { windowManager.removeView(it) }
        borderView = null
    }
}

// ─────────────────────────────────────────────────────────────
// Custom View — draws animated sine-wave border on all 4 edges
// ─────────────────────────────────────────────────────────────
class BorderWaveView(context: Context) : View(context) {

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 6f
        color = Color.TRANSPARENT
    }

    private var phase = 0f
    private var mode  = MaxBorderAnimService.MODE_IDLE
    private val handler = Handler(Looper.getMainLooper())
    private val frameRate = 16L  // ~60fps

    private val ticker = object : Runnable {
        override fun run() {
            phase += 0.06f
            if (phase > (Math.PI * 2).toFloat()) phase -= (Math.PI * 2).toFloat()
            invalidate()
            handler.postDelayed(this, frameRate)
        }
    }

    init {
        handler.post(ticker)
    }

    fun setMode(newMode: String) {
        mode = newMode
        invalidate()
    }

    fun stopAnimation() {
        handler.removeCallbacks(ticker)
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (mode == MaxBorderAnimService.MODE_IDLE) return

        val baseColor = when (mode) {
            MaxBorderAnimService.MODE_USER -> Color.parseColor("#FF2196F3") // Blue
            MaxBorderAnimService.MODE_MAX  -> Color.parseColor("#FFF44336") // Red
            else -> return
        }

        val w = width.toFloat()
        val h = height.toFloat()
        val borderThickness = 10f
        val waveAmp = 12f
        val waveFreq = 0.04f

        // Draw 3 layered waves per edge for depth effect
        for (layer in 0..2) {
            val alpha = when (layer) {
                0 -> 255
                1 -> 160
                else -> 80
            }
            val phaseOffset = layer * 0.8f
            paint.color = setAlpha(baseColor, alpha)
            paint.strokeWidth = when (layer) {
                0 -> 5f
                1 -> 3f
                else -> 2f
            }

            // TOP edge (left → right)
            val topPath = Path()
            topPath.moveTo(0f, borderThickness)
            for (x in 0..w.toInt() step 4) {
                val y = borderThickness + sin((x * waveFreq + phase + phaseOffset).toDouble()).toFloat() * waveAmp
                if (x == 0) topPath.moveTo(x.toFloat(), y)
                else topPath.lineTo(x.toFloat(), y)
            }
            canvas.drawPath(topPath, paint)

            // BOTTOM edge (left → right)
            val botPath = Path()
            for (x in 0..w.toInt() step 4) {
                val y = (h - borderThickness) + sin((x * waveFreq + phase + phaseOffset + Math.PI).toDouble()).toFloat() * waveAmp
                if (x == 0) botPath.moveTo(x.toFloat(), y)
                else botPath.lineTo(x.toFloat(), y)
            }
            canvas.drawPath(botPath, paint)

            // LEFT edge (top → bottom)
            val leftPath = Path()
            for (y in 0..h.toInt() step 4) {
                val x = borderThickness + sin((y * waveFreq + phase + phaseOffset).toDouble()).toFloat() * waveAmp
                if (y == 0) leftPath.moveTo(x, y.toFloat())
                else leftPath.lineTo(x, y.toFloat())
            }
            canvas.drawPath(leftPath, paint)

            // RIGHT edge (top → bottom)
            val rightPath = Path()
            for (y in 0..h.toInt() step 4) {
                val x = (w - borderThickness) + sin((y * waveFreq + phase + phaseOffset + Math.PI).toDouble()).toFloat() * waveAmp
                if (y == 0) rightPath.moveTo(x, y.toFloat())
                else rightPath.lineTo(x, y.toFloat())
            }
            canvas.drawPath(rightPath, paint)
        }
    }

    private fun setAlpha(color: Int, alpha: Int): Int {
        return (color and 0x00FFFFFF) or (alpha shl 24)
    }
}
