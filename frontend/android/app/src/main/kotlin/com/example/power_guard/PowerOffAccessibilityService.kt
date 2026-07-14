package com.example.power_guard

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class PowerOffAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("PowerGuard", "Accessibility Service Connected")
        val info = serviceInfo
        info.flags = info.flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Fallback: Detect if the system Global Actions (power menu) window state shifts
        if (event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val className = event.className
            if (className != null && (className.toString().contains("GlobalActionsDialog") || className.toString().contains("PowerShare") || className.toString().contains("Shutdown"))) {
                Log.d("PowerGuard", "Power dialog window active, launching Flutter overlay challenge.")
                launchChallengeScreen()
            }
        }
    }

    override fun onInterrupt() {
        Log.d("PowerGuard", "Accessibility Service Interrupted")
    }

    override fun onKeyEvent(event: KeyEvent?): Boolean {
        if (event == null) return false
        val keyCode = event.keyCode
        val action = event.action

        // Intercept KeyCode 26 (KEYCODE_POWER)
        if (keyCode == KeyEvent.KEYCODE_POWER) {
            Log.d("PowerGuard", "Power key press intercepted: action = $action")
            if (action == KeyEvent.ACTION_DOWN) {
                // Launch our un-dismissable Flutter activity instantly
                launchChallengeScreen()
                return true // Consume key event (prevents default system power dialog from rendering)
            }
        }
        return super.onKeyEvent(event)
    }

    private fun launchChallengeScreen() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("trigger_challenge", true)
        }
        startActivity(intent)
    }
}
