package foundation.openwallet.mdoc.datatransfer

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.activity.ComponentActivity
import eu.europa.ec.eudi.iso18013.transfer.TransferEvent
import eu.europa.ec.eudi.iso18013.transfer.engagement.NfcEngagementService
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

@OptIn(ExperimentalEncodingApi::class)
class MdocDataTransfer(
    context: Context,
    private val currentActivity: Activity,
    private val sendEvent: (name: String, body: Map<String, Any?>?) -> Unit
) {
    companion object {
        private val TAG = Companion::class.java.simpleName

        /**
         * The transfer manager is a process-wide singleton, so its listener list outlives any single
         * [MdocDataTransfer]. JavaScript drops its instance on `shutdown()` and builds a new one on the
         * next call, which runs `initialize` again, so without tracking the registered listener every
         * session would add another one: each event would then be delivered once per session ever
         * started, and every stale instance would keep [currentActivity] alive.
         */
        private var registeredListener: TransferEvent.Listener? = null
    }

    private val transferManager get() = MdocDataTransferManager.transferManager.value

    /** Resolves the pending `startQrEngagement` call. */
    var onQrEngagementReady: ((qrCode: String) -> Unit)? = null

    /** Rejects the pending `startQrEngagement` call. */
    var onEngagementError: ((error: Throwable) -> Unit)? = null

    private val transferEventListener = TransferEvent.Listener { event ->
        when (event) {
            is TransferEvent.QrEngagementReady -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.QrEngagementReady")
                onQrEngagementReady?.let { it(event.qrCode) }
            }

            is TransferEvent.Connecting -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Connecting")
            }

            is TransferEvent.Connected -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Connected")
            }

            is TransferEvent.Disconnected -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Disconnected")
            }

            is TransferEvent.Error -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Error", event.error)
                // Both paths matter: the pending engagement has to be rejected or its promise never
                // settles, and the event lets JavaScript observe failures outside an engagement.
                onEngagementError?.let { it(event.error) }
                sendEvent(
                    MdocDataTransferEvent.ON_ERROR,
                    mapOf("error" to (event.error.message ?: event.error.toString()))
                )
            }

            is TransferEvent.Redirect -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Redirect")
            }

            is TransferEvent.RequestReceived -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.RequestReceived")
                sendEvent(
                    MdocDataTransferEvent.ON_REQUEST_RECEIVED,
                    mapOf(
                        ("deviceRequest" to Base64.Default.encode(event.deviceRequestBytes)),
                        ("sessionTranscript" to Base64.Default.encode(event.sessionTranscriptBytes))
                    )
                )
            }

            is TransferEvent.ResponseSent -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.ResponseSent")
                sendEvent(
                    MdocDataTransferEvent.ON_RESPONSE_SENT,
                    null
                )
            }

            // Only emitted for the app-to-app flow, which this module does not support. Listeners are
            // dispatched with `forEach`, so throwing here would also stop delivery to every listener
            // after this one.
            is TransferEvent.IntentToSend -> {
                Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.IntentToSend, ignoring")
            }
        }
    }

    init {
        MdocDataTransferManager.init(context)

        registeredListener?.let { transferManager.removeTransferEventListener(it) }
        transferManager.addTransferEventListener(transferEventListener)
        registeredListener = transferEventListener
    }

    fun startQrEngagement() {
        // The transfer manager refuses to start while a previous session is still marked as started,
        // and reports that only as an error event. `sendResponse` does not clear that flag, so without
        // tearing the previous session down first a completed presentation blocks every later
        // engagement. Stopping is a no-op when nothing is in progress.
        transferManager.stopPresentation(
            sendSessionTerminationMessage = false,
            useTransportSpecificSessionTermination = false
        )
        transferManager.startQrEngagement()
    }

    fun respond(deviceResponse: ByteArray) {
        transferManager.sendResponse(deviceResponse)
    }

    fun enableNfc() {
        NfcEngagementService.enable(currentActivity as ComponentActivity)
    }

    fun disableNfc() {
        NfcEngagementService.disable(currentActivity as ComponentActivity)
    }

    fun shutdown() {
        disableNfc()
        transferManager.stopPresentation(
            sendSessionTerminationMessage = true,
            useTransportSpecificSessionTermination = true
        )

        transferManager.removeTransferEventListener(transferEventListener)
        if (registeredListener === transferEventListener) {
            registeredListener = null
        }

        onQrEngagementReady = null
        onEngagementError = null
    }
}
