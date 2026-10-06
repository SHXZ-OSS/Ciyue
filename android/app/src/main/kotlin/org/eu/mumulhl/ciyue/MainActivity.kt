package org.eu.mumulhl.ciyue

import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.core.net.toUri
import androidx.core.view.WindowCompat
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        const val OPEN_DICTIONARY_DOCUMENT_TREE = 0
        const val CREATE_FILE = 1
        const val GET_DIRECTORY = 2
        const val REQUEST_OVERLAY_PERMISSION = 3
        const val OPEN_AUDIO_DOCUMENT_TREE = 4
        const val OPEN_HUNSPELL_DOCUMENT_TREE = 5
        const val REQUEST_MDM_OAUTH = 6

        const val MDM_PACKAGE = "com.shxzhy.mdm"
        const val MDM_OAUTH_ACTIVITY = "com.shxzhy.mdm.ui.oauth.OAuthAuthorizeActivity"
    }

    private lateinit var configurator: EngineConfigurator

    private fun enableEdgeToEdge() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }

    private fun openDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_DICTIONARY_DOCUMENT_TREE)
    }

    private fun openAudioDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_AUDIO_DOCUMENT_TREE)
    }

    private fun openHunspellDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, OPEN_HUNSPELL_DOCUMENT_TREE)
    }

    private fun createFile() {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            setType("application/json")
            putExtra(Intent.EXTRA_TITLE, "ciyue.json")
        }
        startActivityForResult(intent, CREATE_FILE)
    }

    private fun getDirectory() {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
        startActivityForResult(intent, GET_DIRECTORY)
    }

    private fun setSecureFlag(secure: Boolean) {
        if (secure) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onActivityResult(
        requestCode: Int, resultCode: Int, data: Intent?
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_MDM_OAUTH -> {
                ensureConfigurator()
                configurator.onMdmOAuthResult(resultCode, data)
                return
            }
        }

        if (resultCode == RESULT_OK) {
            when (requestCode) {
                OPEN_DICTIONARY_DOCUMENT_TREE -> openDocumentTree(data, "dictionaries")
                OPEN_AUDIO_DOCUMENT_TREE -> openDocumentTree(data, "audios")
                OPEN_HUNSPELL_DOCUMENT_TREE -> openDocumentTree(data, "hunspell")
                CREATE_FILE -> createFileHandler(data)
                GET_DIRECTORY -> getDirectoryHandler(data)
                REQUEST_OVERLAY_PERMISSION -> {}
            }
        }
    }

    /** Launches the school MDM OAuth consent activity with PKCE parameters.
     *  Returns false when the MDM client is not installed. */
    private fun startMdmAuthorize(arguments: Map<*, *>): Boolean {
        val intent = Intent().apply {
            setClassName(MDM_PACKAGE, MDM_OAUTH_ACTIVITY)
            putExtra("client_id", arguments["client_id"] as String)
            putExtra("redirect_uri", arguments["redirect_uri"] as String)
            putExtra("code_challenge", arguments["code_challenge"] as String)
            putExtra("code_challenge_method", arguments["code_challenge_method"] as String)
            putExtra("scope", arguments["scope"] as? String ?: "openid profile")
            arguments["state"]?.let { putExtra("state", it as String) }
        }
        return try {
            startActivityForResult(intent, REQUEST_MDM_OAUTH)
            true
        } catch (error: android.content.ActivityNotFoundException) {
            false
        }
    }

    private fun getDirectoryHandler(data: Intent?) {
        data?.data?.also { uri ->
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            )
            configurator.methodChannel!!.invokeMethod("getDirectory", uri.toString())
        }
    }

    private fun createFileHandler(data: Intent?) {
        data?.data?.also { uri ->
            contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(configurator.exportContent.toByteArray())
                configurator.exportContent = ""
            }
        }
    }

    private fun openDocumentTree(data: Intent?, destination: String) {
        data?.data?.also { uri ->
            val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION
            contentResolver.takePersistableUriPermission(
                uri, takeFlags
            )
            configurator.copyDirectory(uri, destination)
        }
    }

    private fun ensureConfigurator() {
        if (!::configurator.isInitialized) {
            configurator = EngineConfigurator(this)
            configurator.callback = object : EngineConfigurator.Callback {
                override fun onOpenDirectory() = openDirectory()
                override fun onOpenAudioDirectory() = openAudioDirectory()
                override fun onOpenHunspellDirectory() = openHunspellDirectory()
                override fun onCreateFile() = createFile()
                override fun onGetDirectory() = getDirectory()
                override fun onSetSecureFlag(secure: Boolean) = setSecureFlag(secure)
                override fun onMdmAuthorize(arguments: Map<*, *>): Boolean =
                    startMdmAuthorize(arguments)
            }
        }
    }

    override fun onDestroy() {
        if (::configurator.isInitialized) {
            configurator.dispose()
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureConfigurator()
        configurator.configure(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        ensureConfigurator()
        handleProcessTextIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleProcessTextIntent(intent)
    }

    private fun handleProcessTextIntent(intent: Intent?) {
        if (intent?.action == Intent.ACTION_PROCESS_TEXT) {
            val text = TextIntentUtils.extractText(intent)
            configurator.handleProcessText(text)
        }
    }
}
