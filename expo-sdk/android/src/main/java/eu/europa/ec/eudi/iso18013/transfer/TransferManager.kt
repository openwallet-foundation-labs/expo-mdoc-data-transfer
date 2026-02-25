package eu.europa.ec.eudi.iso18013.transfer

import android.content.Context
import android.content.Intent
import eu.europa.ec.eudi.iso18013.transfer.engagement.DeviceRetrievalMethod
import eu.europa.ec.eudi.iso18013.transfer.engagement.NfcEngagementService

interface TransferManager : TransferEvent.Listenable {
    fun setRetrievalMethods(retrievalMethods: List<DeviceRetrievalMethod>): TransferManager

    fun setupNfcEngagement(service: NfcEngagementService): TransferManager

    fun startQrEngagement()


    fun startEngagementToApp(intent: Intent)

    fun sendResponse(deviceResponseBytes: ByteArray)

    fun stopPresentation(
        sendSessionTerminationMessage: Boolean = true,
        useTransportSpecificSessionTermination: Boolean = false,
    )

    companion object {
        @JvmStatic
        fun getDefault(
            context: Context,
            retrievalMethods: List<DeviceRetrievalMethod>? = null,
        ): TransferManager = TransferManagerImpl(context) {
            retrievalMethods?.let { retrievalMethods(it) }
        }
    }
}
