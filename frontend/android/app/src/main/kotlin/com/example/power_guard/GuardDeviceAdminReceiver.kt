package com.example.power_guard

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast
import android.util.Log

class GuardDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d("PowerGuard", "Device Admin Enabled")
        Toast.makeText(context, "Power Guard Admin Enabled", Toast.LENGTH_SHORT).show()
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d("PowerGuard", "Device Admin Disabled")
        Toast.makeText(context, "Power Guard Admin Disabled", Toast.LENGTH_SHORT).show()
    }
}
