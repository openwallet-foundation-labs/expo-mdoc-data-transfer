package eu.europa.ec.eudi.iso18013.transfer

import android.content.Intent
import java.net.URI

sealed interface TransferEvent {
    data class QrEngagementReady(val qrCode: String) : TransferEvent

    data object Connecting : TransferEvent

    data object Connected : TransferEvent

    data class RequestReceived(
        val deviceRequestBytes: ByteArray,
        val sessionTranscriptBytes: ByteArray
    ) : TransferEvent

    data object ResponseSent : TransferEvent

    data class Redirect(val redirectUri: URI) : TransferEvent

    data class IntentToSend(val intent: Intent) : TransferEvent

    data object Disconnected : TransferEvent

    data class Error(val error: Throwable) : TransferEvent

    fun interface Listener {
        fun onTransferEvent(event: TransferEvent)
    }

    interface Listenable {
        fun addTransferEventListener(listener: Listener): Listenable

        fun removeTransferEventListener(listener: Listener): Listenable

        fun removeAllTransferEventListeners(): Listenable
    }
}
