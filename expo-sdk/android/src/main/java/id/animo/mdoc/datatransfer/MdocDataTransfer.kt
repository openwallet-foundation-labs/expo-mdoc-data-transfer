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
    sendEvent: (name: String, body: Map<String, Any?>?) -> Unit
) {
    companion object {
        private val TAG = Companion::class.java.simpleName
    }

    init {
        MdocDataTransferManager.init(context)

        val transferEventListener = TransferEvent.Listener { event ->
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
                    Log.d(TAG, ":::mdoc-data-transfer::: TransferEvent.Error")
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

                // Can be removed with a cleanup
                is TransferEvent.IntentToSend -> TODO()
            }
        }

        MdocDataTransferManager.transferManager.value.addTransferEventListener(transferEventListener)
    }

    var onQrEngagementReady: ((qrCode: String) -> Unit)? = null

    fun startQrEngagement() {
        MdocDataTransferManager.transferManager.value.startQrEngagement()
    }

    fun respond(deviceResponse: ByteArray) {
        MdocDataTransferManager.transferManager.value.sendResponse(deviceResponse)
    }

    fun enableNfc() {
        NfcEngagementService.enable(currentActivity as ComponentActivity)
    }

    fun disableNfc() {
        NfcEngagementService.disable(currentActivity as ComponentActivity)
    }

    fun shutdown() {
        disableNfc()
        MdocDataTransferManager.transferManager.value.stopPresentation(
            sendSessionTerminationMessage = true,
            useTransportSpecificSessionTermination = true
        )
    }
}
