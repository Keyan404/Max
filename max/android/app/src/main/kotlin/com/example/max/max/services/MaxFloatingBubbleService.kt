package com.example.max.max.services

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import com.example.max.max.MainActivity

class MaxFloatingBubbleService : Service() {

    private lateinit var windowManager: WindowManager
    private var floatingView: FrameLayout? = null
    private var params: WindowManager.LayoutParams? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        createFloatingBubble()
    }

    private fun createFloatingBubble() {
        // Inflate or programmatically build a circular, glassmorphic layout
        floatingView = FrameLayout(this)
        
        // Circular bubble design
        val bubble = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_btn_speak_now)
            setBackgroundResource(android.R.drawable.presence_online) // Circular background
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            alpha = 0.9f
        }
        
        val sizeInDp = 60
        val scale = resources.displayMetrics.density
        val sizeInPx = (sizeInDp * scale + 0.5f).toInt()
        
        floatingView?.addView(bubble, FrameLayout.LayoutParams(sizeInPx, sizeInPx))

        // Set layout parameters for overlay
        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            layoutFlag,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = 100
            y = 100
        }

        windowManager.addView(floatingView, params)

        // Setup Drag & Click Touch Listener
        floatingView?.setOnTouchListener(object : View.OnTouchListener {
            private var initialX = 0
            private var initialY = 0
            private var initialTouchX = 0.0f
            private var initialTouchY = 0.0f
            private var isDrag = false

            override fun onTouch(v: View, event: MotionEvent): Boolean {
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        initialX = params?.x ?: 0
                        initialY = params?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        isDrag = false
                        return true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val deltaX = (event.rawX - initialTouchX).toInt()
                        val deltaY = (event.rawY - initialTouchY).toInt()
                        
                        // Prevent minor jitters from causing drag action
                        if (Math.abs(deltaX) > 10 || Math.abs(deltaY) > 10) {
                            isDrag = true
                        }
                        
                        params?.x = initialX + deltaX
                        params?.y = initialY + deltaY
                        windowManager.updateViewLayout(floatingView, params)
                        return true
                    }
                    MotionEvent.ACTION_UP -> {
                        if (!isDrag) {
                            // Single Click Action: Launch main voice overlay page
                            val intent = Intent(this@MaxFloatingBubbleService, MainActivity::class.java).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                                action = "OPEN_VOICE_MODE"
                            }
                            startActivity(intent)
                        }
                        return true
                    }
                }
                return false
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        if (floatingView != null) {
            windowManager.removeView(floatingView)
        }
    }
}
