package com.iml1s.termux_flutter_ide

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.termux.terminal.TerminalSession
import com.termux.terminal.TerminalSessionClient
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * Manager class for native Termux terminal sessions with true PTY support.
 * Each session is a real shell process with persistent state (CWD, env vars, etc).
 */
class TermuxTerminalManager(private val context: Context) {

    companion object {
        private const val TAG = "TermuxTerminalManager"
        private const val TERMUX_PREFIX = "/data/data/com.termux/files/usr"
        private const val TERMUX_HOME = "/data/data/com.termux/files/home"
        private const val DEFAULT_SHELL = "$TERMUX_PREFIX/bin/bash"
        private const val TRANSCRIPT_ROWS = 2000
    }

    // Active terminal sessions keyed by session ID
    private val sessions = ConcurrentHashMap<String, TerminalSession>()
    
    // Main thread handler for session callbacks
    private val mainHandler = Handler(Looper.getMainLooper())
    
    // Channel for sending output back to Flutter
    private var outputChannel: MethodChannel? = null

    fun setOutputChannel(channel: MethodChannel) {
        outputChannel = channel
    }

    /**
     * Create a new terminal session with full PTY support.
     * @param cwd Initial working directory (defaults to Termux home)
     * @param shellPath Path to the shell executable (defaults to bash)
     * @return Session ID for referencing this session
     */
    fun createSession(cwd: String? = null, shellPath: String? = null): String {
        val sessionId = UUID.randomUUID().toString()
        val workingDir = cwd ?: TERMUX_HOME
        val shell = shellPath ?: DEFAULT_SHELL

        Log.d(TAG, "Creating session $sessionId with shell=$shell, cwd=$workingDir")

        // Build environment variables
        val env = buildEnvironment()

        // Create session client for callbacks
        val client = SessionClient(sessionId)

        // Create the terminal session
        val session = TerminalSession(
            shell,           // shellPath
            workingDir,      // cwd
            arrayOf(),       // args
            env,             // environment
            TRANSCRIPT_ROWS, // transcriptRows
            client           // client callback
        )

        sessions[sessionId] = session
        return sessionId
    }

    /**
     * Initialize the terminal emulator for a session.
     * Must be called after createSession with the desired terminal dimensions.
     */
    fun initializeSession(sessionId: String, columns: Int, rows: Int): Boolean {
        val session = sessions[sessionId] ?: run {
            Log.e(TAG, "Session $sessionId not found")
            return false
        }

        try {
            // Initialize emulator - API takes (columns, rows) only in 0.118.0
            session.updateSize(columns, rows)
            Log.d(TAG, "Session $sessionId initialized with ${columns}x${rows}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize session $sessionId: ${e.message}")
            return false
        }
    }

    /**
     * Write input data to a terminal session (user keystrokes, commands, etc).
     */
    fun writeToSession(sessionId: String, data: String): Boolean {
        val session = sessions[sessionId] ?: return false
        val bytes = data.toByteArray(Charsets.UTF_8)
        session.write(bytes, 0, bytes.size)
        return true
    }

    /**
     * Write a single unicode code point to the session.
     */
    fun writeCodePoint(sessionId: String, codePoint: Int, prependEscape: Boolean = false): Boolean {
        val session = sessions[sessionId] ?: return false
        session.writeCodePoint(prependEscape, codePoint)
        return true
    }

    /**
     * Resize a terminal session.
     */
    fun resizeSession(sessionId: String, columns: Int, rows: Int): Boolean {
        val session = sessions[sessionId] ?: return false
        session.updateSize(columns, rows)
        return true
    }

    /**
     * Get the current working directory of a session.
     */
    fun getSessionCwd(sessionId: String): String? {
        return sessions[sessionId]?.cwd
    }

    /**
     * Get the title of a session (set by shell escape sequences).
     */
    fun getSessionTitle(sessionId: String): String? {
        return sessions[sessionId]?.title
    }

    /**
     * Check if a session is still running.
     */
    fun isSessionRunning(sessionId: String): Boolean {
        return sessions[sessionId]?.isRunning == true
    }

    /**
     * Kill and clean up a terminal session.
     */
    fun closeSession(sessionId: String): Boolean {
        val session = sessions.remove(sessionId) ?: return false
        session.finishIfRunning()
        Log.d(TAG, "Session $sessionId closed")
        return true
    }

    /**
     * Close all active sessions.
     */
    fun closeAllSessions() {
        sessions.keys.forEach { closeSession(it) }
    }

    /**
     * Get the number of active sessions.
     */
    fun getSessionCount(): Int = sessions.size

    /**
     * Get list of all active session IDs.
     */
    fun getActiveSessions(): List<String> = sessions.keys.toList()

    /**
     * Build environment variables for terminal session.
     */
    private fun buildEnvironment(): Array<String> {
        return arrayOf(
            "TERM=xterm-256color",
            "HOME=$TERMUX_HOME",
            "PREFIX=$TERMUX_PREFIX",
            "PATH=$TERMUX_PREFIX/bin:$TERMUX_PREFIX/bin/applets",
            "LD_LIBRARY_PATH=$TERMUX_PREFIX/lib",
            "LANG=en_US.UTF-8",
            "COLORTERM=truecolor",
            "TERMUX_VERSION=0.118.0",
            "TMPDIR=$TERMUX_PREFIX/tmp"
        )
    }

    /**
     * Terminal session client that forwards events to Flutter via MethodChannel.
     * Implements TerminalSessionClient interface from Termux 0.118.0.
     */
    private inner class SessionClient(private val sessionId: String) : TerminalSessionClient {

        override fun onTextChanged(changedSession: TerminalSession) {
            // Get screen text using available API
            val emulator = changedSession.emulator ?: return
            
            // Use getScreen().getTranscriptText() for full buffer, or build from rows
            val text = try {
                emulator.screen.getTranscriptText()
            } catch (e: Exception) {
                // Fallback: just notify that text changed
                ""
            }

            // Send screen update to Flutter
            mainHandler.post {
                outputChannel?.invokeMethod("onTerminalOutput", mapOf(
                    "sessionId" to sessionId,
                    "output" to text
                ))
            }
        }

        override fun onTitleChanged(changedSession: TerminalSession) {
            mainHandler.post {
                outputChannel?.invokeMethod("onTitleChanged", mapOf(
                    "sessionId" to sessionId,
                    "title" to changedSession.title
                ))
            }
        }

        override fun onSessionFinished(finishedSession: TerminalSession) {
            val exitCode = finishedSession.exitStatus
            Log.d(TAG, "Session $sessionId finished with exit code $exitCode")
            
            mainHandler.post {
                outputChannel?.invokeMethod("onSessionFinished", mapOf(
                    "sessionId" to sessionId,
                    "exitCode" to exitCode
                ))
            }
        }

        override fun onBell(session: TerminalSession) {
            mainHandler.post {
                outputChannel?.invokeMethod("onBell", mapOf(
                    "sessionId" to sessionId
                ))
            }
        }

        override fun onColorsChanged(changedSession: TerminalSession) {
            // Colors changed - could notify Flutter if needed
        }

        override fun onCopyTextToClipboard(session: TerminalSession, text: String) {
            mainHandler.post {
                outputChannel?.invokeMethod("onCopyToClipboard", mapOf(
                    "sessionId" to sessionId,
                    "text" to text
                ))
            }
        }

        override fun onPasteTextFromClipboard(session: TerminalSession) {
            mainHandler.post {
                outputChannel?.invokeMethod("onPasteFromClipboard", mapOf(
                    "sessionId" to sessionId
                ))
            }
        }

        // Required by TerminalSessionClient in 0.118.0
        override fun onTerminalCursorStateChange(state: Boolean) {
            // Cursor visibility changed - could notify Flutter if needed
        }

        // Required by TerminalSessionClient in 0.118.0
        override fun getTerminalCursorStyle(): Int? {
            // Return null for default cursor style, or 0=block, 1=underline, 2=bar
            return null
        }

        override fun logError(tag: String, message: String) {
            Log.e("$TAG:$tag", message)
        }

        override fun logWarn(tag: String, message: String) {
            Log.w("$TAG:$tag", message)
        }

        override fun logInfo(tag: String, message: String) {
            Log.i("$TAG:$tag", message)
        }

        override fun logDebug(tag: String, message: String) {
            Log.d("$TAG:$tag", message)
        }

        override fun logVerbose(tag: String, message: String) {
            Log.v("$TAG:$tag", message)
        }

        override fun logStackTraceWithMessage(tag: String, message: String, e: Exception) {
            Log.e("$TAG:$tag", message, e)
        }

        override fun logStackTrace(tag: String, e: Exception) {
            Log.e("$TAG:$tag", "Stack trace", e)
        }
    }
}
