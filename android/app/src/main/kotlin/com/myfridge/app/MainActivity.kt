package com.myfridge.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val SETTINGS_CHANNEL = "com.myfridge.app/settings"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SETTINGS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "cameraPermissionStatus" -> result.success(cameraPermissionStatus())
                "openAppSettings" -> {
                    val intent = Intent(
                        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:$packageName"),
                    )
                    startActivity(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cameraPermissionStatus(): String {
        if (
            ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            return "granted"
        }

        val canAskAgain =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                ActivityCompat.shouldShowRequestPermissionRationale(
                    this,
                    Manifest.permission.CAMERA,
                )

        return if (canAskAgain) "denied" else "permanentlyDenied"
    }
}
