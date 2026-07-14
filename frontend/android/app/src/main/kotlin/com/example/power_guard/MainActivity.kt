package com.example.power_guard

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.power_guard/platform_channel"
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled(this))
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                }
                "isDeviceAdminEnabled" -> {
                    result.success(isDeviceAdminEnabled())
                }
                "requestDeviceAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
                }
                "lockDevice" -> {
                    val locked = lockDevice()
                    result.success(locked)
                }
                "checkTriggerIntent" -> {
                    // Check if launched via Accessibility Intercept
                    val trigger = intent?.getBooleanExtra("trigger_challenge", false) ?: false
                    // Reset intent extra so we don't trigger repeatedly
                    if (trigger) {
                        intent?.removeExtra("trigger_challenge")
                    }
                    result.success(trigger)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val trigger = intent.getBooleanExtra("trigger_challenge", false)
        if (trigger) {
            intent.removeExtra("trigger_challenge")
            // Notify Flutter directly via method channel
            methodChannel?.invokeMethod("onPowerOffIntercepted", null)
        }
    }

    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        val expectedComponentName = ComponentName(context, PowerOffAccessibilityService::class.java)
        val enabledServicesSetting = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val colonSplitter = TextUtils.SimpleStringSplitter(':')
        colonSplitter.setString(enabledServicesSetting)
        while (colonSplitter.hasNext()) {
            val componentNameString = colonSplitter.next()
            val enabledService = ComponentName.unflattenFromString(componentNameString)
            if (enabledService != null && enabledService == expectedComponentName) {
                return true
            }
        }
        return false
    }

    private fun isDeviceAdminEnabled(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, GuardDeviceAdminReceiver::class.java)
        return dpm.isAdminActive(adminComponent)
    }

    private fun requestDeviceAdmin() {
        val adminComponent = ComponentName(this, GuardDeviceAdminReceiver::class.java)
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
            putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required to secure lock your phone on unauthorized shutdown attempts.")
        }
        startActivity(intent)
    }

    private fun lockDevice(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val adminComponent = ComponentName(this, GuardDeviceAdminReceiver::class.java)
        return if (dpm.isAdminActive(adminComponent)) {
            dpm.lockNow()
            true
        } else {
            false
        }
    }
}
