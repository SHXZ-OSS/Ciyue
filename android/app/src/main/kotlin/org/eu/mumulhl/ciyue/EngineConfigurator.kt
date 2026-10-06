package org.eu.mumulhl.ciyue

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.net.toUri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class EngineConfigurator(context: Context) {
    private val context = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    var methodChannel: MethodChannel? = null
    private var pendingProcessText: ProcessTextRequest? = null
    private var nextProcessTextId = 0L
    var exportContent = ""

    // Pending result of an in-flight MDM OAuth authorization; the school MDM
    // client returns the authorization code through the launching activity.
    private var pendingMdmOAuthResult: MethodChannel.Result? = null

    private data class ProcessTextRequest(val id: Long, val text: String) {
        fun toMap(): Map<String, Any> = mapOf("id" to id, "text" to text)
    }

    interface Callback {
        fun onOpenDirectory() {}
        fun onOpenAudioDirectory() {}
        fun onOpenHunspellDirectory() {}
        fun onCreateFile() {}
        fun onGetDirectory() {}
        fun onSetSecureFlag(secure: Boolean) {}
        fun onDismissFloatingWindow() {}

        /** Starts the MDM OAuth consent activity; false when unavailable. */
        fun onMdmAuthorize(arguments: Map<*, *>): Boolean = false
    }

    var callback: Callback? = null

    fun configure(flutterEngine: FlutterEngine) {
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.eu.mumulhl.ciyue").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "openDirectory" -> {
                        callback?.onOpenDirectory()
                        result.success(0)
                    }

                    "getPendingProcessText" -> {
                        result.success(pendingProcessText?.toMap())
                    }

                    "processTextHandled" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val id = (arguments?.get("id") as? Number)?.toLong()
                        if (id != null && id == pendingProcessText?.id) {
                            pendingProcessText = null
                        }
                        result.success(0)
                    }

                    "openAudioDirectory" -> {
                        callback?.onOpenAudioDirectory()
                        result.success(0)
                    }

                    "openHunspellDirectory" -> {
                        callback?.onOpenHunspellDirectory()
                        result.success(0)
                    }

                    "createFile" -> {
                        exportContent = call.arguments as String
                        callback?.onCreateFile()
                        result.success(0)
                    }

                    "getDirectory" -> {
                        callback?.onGetDirectory()
                        result.success(0)
                    }

                    "writeFile" -> {
                        val arguments = call.arguments as Map<*, *>
                        writeFile(
                            arguments["directory"] as String,
                            arguments["filename"] as String,
                            arguments["content"] as String
                        )
                        result.success(0)
                    }

                    "setSecureFlag" -> {
                        callback?.onSetSecureFlag(call.arguments as Boolean)
                        result.success(0)
                    }

                    "dismissFloatingWindow" -> {
                        callback?.onDismissFloatingWindow()
                        result.success(0)
                    }

                    "updateDictionaries" -> {
                        val uri = (call.arguments as String).toUri()
                        copyDirectory(uri, "dictionaries")
                        result.success(0)
                    }

                    "mdmIdentity" -> {
                        result.success(readMdmIdentity())
                    }

                    "mdmAuthorize" -> {
                        val arguments = call.arguments as? Map<*, *>
                        if (arguments == null) {
                            result.error("invalid_request", "Missing arguments", null)
                        } else {
                            pendingMdmOAuthResult?.let {
                                it.error("another_in_progress", "Authorization already running", null)
                            }
                            val currentCallback = callback
                            if (currentCallback == null) {
                                result.error("mdm_unavailable", "No activity", null)
                            } else {
                                pendingMdmOAuthResult = result
                                if (!currentCallback.onMdmAuthorize(arguments)) {
                                    pendingMdmOAuthResult = null
                                    result.error("mdm_unavailable", "MDM client not installed", null)
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun writeFile(directory: String, filename: String, content: String) {
        val directoryFile = DocumentFile.fromTreeUri(context, directory.toUri())
        val file = directoryFile!!.findFile(filename)
        if (file == null) {
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.uri.let { context.contentResolver.openOutputStream(it) }.use { outputStream ->
                outputStream!!.write(content.toByteArray())
            }

        } else {
            file.delete()
            val newFile = directoryFile.createFile("application/json", filename)
            newFile!!.uri.let { context.contentResolver.openOutputStream(it) }.use { outputStream ->
                outputStream!!.write(content.toByteArray())
            }
        }
    }

    fun copyDirectory(uri: Uri, destination: String) {
        val channel = methodChannel ?: return
        channel.invokeMethod("showLoadingDialog", null)

        ioExecutor.execute {
            try {
                val documents = DocumentFile.fromTreeUri(context, uri)
                    ?: throw IOException("Unable to access selected directory")
                copy(documents, File(context.filesDir, destination))

                mainHandler.post {
                    when (destination) {
                        "dictionaries" -> channel.invokeMethod("inputDirectory", uri.toString())
                        "audios" -> channel.invokeMethod("inputAudioDirectory", uri.toString())
                        "hunspell" -> channel.invokeMethod("inputHunspellDirectory", uri.toString())
                    }
                }
            } catch (error: Exception) {
                mainHandler.post {
                    channel.invokeMethod(
                        "copyDirectoryError",
                        error.message ?: error.javaClass.simpleName,
                    )
                }
            }
        }
    }

    private fun copy(source: DocumentFile, target: File) {
        if (!target.exists() && !target.mkdirs()) {
            throw IOException("Unable to create destination directory: $target")
        }
        source.listFiles().forEach { file ->
            if (file.isFile) {
                BufferedInputStream(context.contentResolver.openInputStream(file.uri)).use { input ->
                    BufferedOutputStream(
                        File(
                            target,
                            file.name ?: ""
                        ).outputStream()
                    ).use { output ->
                        input.copyTo(output)
                    }
                }
            } else {
                copy(file, File(target, file.name ?: ""))
            }
        }
    }

    fun dispose() {
        mainHandler.removeCallbacksAndMessages(null)
        ioExecutor.shutdownNow()
        pendingMdmOAuthResult = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        callback = null
    }

    /** Reads the logged-in student identity from the school MDM client. */
    private fun readMdmIdentity(): Map<String, Any>? {
        return try {
            val bundle = context.contentResolver.call(
                Uri.parse("content://com.shxzhy.mdm.info"),
                "identity",
                null,
                null
            ) ?: return null
            val userId = bundle.getInt("user_id", -1)
            val name = bundle.getString("name")
            val username = bundle.getString("username")
            val serverUrl = bundle.getString("server_url")
            if (userId == -1 || name == null || username == null || serverUrl == null) {
                null
            } else {
                mapOf(
                    "user_id" to userId,
                    "name" to name,
                    "username" to username,
                    "server_url" to serverUrl
                )
            }
        } catch (error: Exception) {
            null
        }
    }

    /** Resolves the pending OAuth authorization once the MDM activity returns. */
    fun onMdmOAuthResult(resultCode: Int, data: Intent?) {
        val pending = pendingMdmOAuthResult ?: return
        pendingMdmOAuthResult = null
        if (resultCode == android.app.Activity.RESULT_OK) {
            val code = data?.getStringExtra("code")
            if (code == null) {
                pending.error("invalid_response", "No authorization code", null)
                return
            }
            pending.success(
                mapOf(
                    "code" to code,
                    "server_url" to (data.getStringExtra("server_url") ?: ""),
                    "state" to (data.getStringExtra("state") ?: "")
                )
            )
        } else {
            onMdmOAuthError(
                data?.getStringExtra("error") ?: "access_denied",
                data?.getStringExtra("error_description")
            )
        }
    }

    /** Fails the pending OAuth authorization with [error]. */
    fun onMdmOAuthError(error: String, errorDescription: String?) {
        val pending = pendingMdmOAuthResult ?: return
        pendingMdmOAuthResult = null
        pending.error(error, errorDescription, null)
    }

    fun handleProcessText(text: String) {
        if (text.isBlank()) {
            return
        }

        // Keep the latest request until Dart acknowledges it. The method call
        // may arrive before the Dart entrypoint has installed its handler.
        val request = ProcessTextRequest(++nextProcessTextId, text)
        pendingProcessText = request
        methodChannel?.invokeMethod("processText", request.toMap())
    }
}
