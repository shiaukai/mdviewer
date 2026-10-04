package tw.easier.mdviewer

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /** Files received before Dart asked for them. */
    private val pendingFiles = mutableListOf<String>()
    private var dartReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mdviewer/files").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "getInitialFiles") {
                    result.success(ArrayList(pendingFiles))
                    pendingFiles.clear()
                    dartReady = true
                } else {
                    result.notImplemented()
                }
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    /** "Open with MD Viewer" from a file manager, mail app, etc. */
    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        val uri = intent.data ?: return
        // Don't re-open the same file if the activity is recreated.
        intent.action = null
        val path = copyToCache(uri) ?: return
        if (dartReady) {
            channel?.invokeMethod("openFile", path)
        } else {
            pendingFiles.add(path)
        }
    }

    /** content:// URIs aren't file paths; copy the bytes somewhere Dart can read. */
    private fun copyToCache(uri: Uri): String? = try {
        val name = File(displayName(uri) ?: "document.md").name.ifBlank { "document.md" }
        val dir = File(cacheDir, "incoming").apply { mkdirs() }
        val target = File(dir, name)
        contentResolver.openInputStream(uri)?.use { input ->
            target.outputStream().use { input.copyTo(it) }
            target.absolutePath
        }
    } catch (e: Exception) {
        null
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) return c.getString(0)
        }
        return uri.lastPathSegment
    }
}
