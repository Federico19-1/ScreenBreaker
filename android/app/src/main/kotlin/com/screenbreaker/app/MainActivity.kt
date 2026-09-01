package com.screenbreaker.app

import android.Manifest
import com.pravera.flutter_foreground_task.FlutterForegroundTaskLifecycleListener
import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import com.pravera.flutter_foreground_task.FlutterForegroundTaskStarter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    companion object {
        // `configureFlutterEngine` can be called more than once across the app's
        // lifetime (activity recreation), so make sure the listener is installed
        // only a single time.
        private var pluginsRegisteredOnBackgroundTask = false

        private const val FULL_SCREEN_INTENT_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Lets Dart request the USE_FULL_SCREEN_INTENT permission. On Android 14+
        // this permission is denied by default for newly installed apps targeting
        // SDK 34+, and no Flutter plugin exposes it, so we ask the OS directly.
        // (setMethodCallHandler simply replaces any previous handler, so it is
        // safe to call again if the activity is recreated.)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "screenbreaker/permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFullScreenIntent" -> {
                    if (checkSelfPermission(Manifest.permission.USE_FULL_SCREEN_INTENT) ==
                        android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        requestPermissions(
                            arrayOf(Manifest.permission.USE_FULL_SCREEN_INTENT),
                            FULL_SCREEN_INTENT_REQUEST_CODE,
                        )
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // The flutter_foreground_task package runs the background TaskHandler on
        // its own FlutterEngine (a separate isolate). By default NO plugins are
        // registered on that engine, so shared_preferences, usage_stats and
        // flutter_local_notifications would throw MissingPluginException there.
        //
        // The plugin exposes a lifecycle listener whose onEngineCreate callback
        // is fired right before the task engine starts running the handler. We
        // use it to register every plugin on the background engine so the
        // monitoring loop works even while the app is in the background.
        if (!pluginsRegisteredOnBackgroundTask) {
            pluginsRegisteredOnBackgroundTask = true
            FlutterForegroundTaskPlugin.addTaskLifecycleListener(
                object : FlutterForegroundTaskLifecycleListener {
                    override fun onEngineCreate(engine: FlutterEngine?) {
                        engine?.let { GeneratedPluginRegistrant.registerWith(it) }
                    }

                    override fun onTaskStart(starter: FlutterForegroundTaskStarter) {}

                    override fun onTaskRepeatEvent() {}

                    override fun onTaskDestroy() {}

                    override fun onEngineWillDestroy() {}
                }
            )
        }
    }
}