package eu.europa.ec.eudi.iso18013.transfer

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.net.toUri
import com.android.identity.android.mdoc.deviceretrieval.DeviceRetrievalHelper
import eu.europa.ec.eudi.iso18013.transfer.engagement.DeviceRetrievalMethod
import eu.europa.ec.eudi.iso18013.transfer.engagement.NfcEngagementService
import eu.europa.ec.eudi.iso18013.transfer.internal.EngagementToApp
import eu.europa.ec.eudi.iso18013.transfer.internal.QrEngagement
import eu.europa.ec.eudi.iso18013.transfer.internal.TAG
import eu.europa.ec.eudi.iso18013.transfer.internal.stopPresentation
import eu.europa.ec.eudi.iso18013.transfer.internal.transportOptions
import org.multipaz.mdoc.origininfo.OriginInfo
import org.multipaz.mdoc.origininfo.OriginInfoDomain
import org.multipaz.util.Constants

class TransferManagerImpl @JvmOverloads constructor(
    context: Context,
    retrievalMethods: List<DeviceRetrievalMethod>? = null,
) : TransferManager {
    private val context = context.applicationContext

    @JvmSynthetic
    internal var deviceRetrievalHelper: DeviceRetrievalHelper? = null

    @JvmSynthetic
    internal var engagementToApp: EngagementToApp? = null

    @JvmSynthetic
    internal var qrEngagement: QrEngagement? = null

    @JvmSynthetic
    internal var hasStarted = false

    var retrievalMethods: List<DeviceRetrievalMethod> =
        retrievalMethods?.let { listOf(*it.toTypedArray()) } ?: emptyList()
        private set(value) {
            field = listOf(*value.toTypedArray())
        }

    @JvmSynthetic
    internal val transferEventListeners = mutableListOf<TransferEvent.Listener>()

    override fun addTransferEventListener(listener: TransferEvent.Listener) = apply {
        transferEventListeners.add(listener)
    }

    override fun removeTransferEventListener(listener: TransferEvent.Listener) = apply {
        transferEventListeners.remove(listener)
    }

    override fun removeAllTransferEventListeners() = apply {
        transferEventListeners.clear()
    }

    override fun setRetrievalMethods(retrievalMethods: List<DeviceRetrievalMethod>) = apply {
        this.retrievalMethods = retrievalMethods
    }

    override fun startQrEngagement() {
        if (hasStarted) {
            Log.d(this.TAG, TRANSFER_STARTED_MSG)
            transferEventListeners.onTransferEvent(
                TransferEvent.Error(
                    IllegalStateException(
                        TRANSFER_STARTED_MSG,
                    ),
                ),
            )
            return
        }
        qrEngagement = QrEngagement(
            context = context,
            retrievalMethods = retrievalMethods,
            onQrEngagementReady = { qrCode ->
                transferEventListeners.onTransferEvent(
                    TransferEvent.QrEngagementReady(qrCode),
                )
            },
            onConnecting = {
                transferEventListeners.onTransferEvent(TransferEvent.Connecting)
            },
            onDeviceRetrievalHelperReady = { deviceRetrievalHelper ->
                this.deviceRetrievalHelper = deviceRetrievalHelper
                transferEventListeners.onTransferEvent(TransferEvent.Connected)
            },
            onNewDeviceRequest = { deviceRequestBytes ->
                transferEventListeners.onTransferEvent(
                    TransferEvent.RequestReceived(
                        deviceRequestBytes,
                        deviceRetrievalHelper?.sessionTranscript!!,
                    )
                )
            },
            onDisconnected = {
                transferEventListeners.onTransferEvent(TransferEvent.Disconnected)
            },
            onCommunicationError = { error ->
                Log.d(this.TAG, "onError: ${error.message}")
                transferEventListeners.onTransferEvent(TransferEvent.Error(error))
            },
        ).apply { configure() }
        hasStarted = true
    }

    override fun setupNfcEngagement(service: NfcEngagementService) = apply {
        service.apply {
            retrievalMethods = this@TransferManagerImpl.retrievalMethods
            onConnecting = {
                transferEventListeners.onTransferEvent(TransferEvent.Connecting)
            }
            onDeviceRetrievalHelperReady = { deviceRetrievalHelper ->
                this@TransferManagerImpl.deviceRetrievalHelper = deviceRetrievalHelper
                transferEventListeners.onTransferEvent(TransferEvent.Connected)
            }
            onNewDeviceRequest = { deviceRequestBytes ->
                transferEventListeners.onTransferEvent(
                    TransferEvent.RequestReceived(
                        deviceRequestBytes,
                        deviceRetrievalHelper?.sessionTranscript!!
                    )
                )
            }
            onDisconnected = {
                transferEventListeners.onTransferEvent(TransferEvent.Disconnected)
            }
            onCommunicationError = { error ->
                Log.d(this.TAG, "onError: ${error.message}")
                transferEventListeners.onTransferEvent(TransferEvent.Error(error))
            }
        }
    }

    override fun startEngagementToApp(intent: Intent) {
        if (hasStarted) {
            Log.d(this.TAG, TRANSFER_STARTED_MSG)
            transferEventListeners.onTransferEvent(
                TransferEvent.Error(
                    IllegalStateException(
                        TRANSFER_STARTED_MSG,
                    ),
                ),
            )
            return
        }
        Log.d(this.TAG, "New intent $intent")

        var mdocUri: String? = null
        var mdocReferrerUri: String? = null
        if (intent.scheme.equals("mdoc")) {
            val uri = intent.toUri(0).toUri()
            mdocUri = "mdoc://" + uri.authority
            mdocReferrerUri = intent.extras?.getString(Intent.EXTRA_REFERRER)
        }

        if (mdocUri == null) {
            Log.e(this.TAG, "No mdoc:// URI")
            return
        }
        Log.i(this.TAG, "uri: $mdocUri")

        val originInfos = ArrayList<OriginInfo>()
        if (mdocReferrerUri == null) {
            Log.w(this.TAG, "No referrer URI")
        } else {
            Log.i(this.TAG, "referrer: $mdocReferrerUri")
            originInfos.add(OriginInfoDomain(mdocReferrerUri))
        }

        engagementToApp = EngagementToApp(
            context = context,
            dataTransportOptions = retrievalMethods.transportOptions,
            onPresentationReady = { deviceRetrievalHelper ->
                this.deviceRetrievalHelper = deviceRetrievalHelper
                transferEventListeners.onTransferEvent(TransferEvent.Connected)
            },
            onNewRequest = { deviceRequestBytes ->
                transferEventListeners.onTransferEvent(
                    TransferEvent.RequestReceived(
                        deviceRequestBytes,
                        deviceRetrievalHelper?.sessionTranscript!!
                    )
                )
            },
            onDisconnected = {
                transferEventListeners.onTransferEvent(TransferEvent.Disconnected)
            },
            onCommunicationError = { error ->
                Log.d(this.TAG, "onError: ${error.message}")
                transferEventListeners.onTransferEvent(TransferEvent.Error(error))
            },
        ).apply {
            configure(mdocUri, originInfos)
        }
        hasStarted = true
    }

    override fun sendResponse(deviceResponseBytes: ByteArray) {
        deviceRetrievalHelper?.sendDeviceResponse(
            deviceResponseBytes,
            Constants.SESSION_DATA_STATUS_SESSION_TERMINATION
        )
        transferEventListeners.onTransferEvent(TransferEvent.ResponseSent)
    }

    override fun stopPresentation(
        sendSessionTerminationMessage: Boolean,
        useTransportSpecificSessionTermination: Boolean,
    ) {
        deviceRetrievalHelper?.stopPresentation(
            sendSessionTerminationMessage,
            useTransportSpecificSessionTermination,
        )
        disconnect()
    }

    private fun disconnect() {
        qrEngagement?.close()
        destroy()
    }

    private fun destroy() {
        deviceRetrievalHelper = null
        qrEngagement = null
        engagementToApp = null
        hasStarted = false
    }

    companion object {
        private const val TRANSFER_STARTED_MSG = "Transfer has already started."

        private fun Collection<TransferEvent.Listener>.onTransferEvent(event: TransferEvent) {
            forEach { it.onTransferEvent(event) }
        }

        operator fun invoke(context: Context, builder: Builder.() -> Unit): TransferManagerImpl {
            val builder = Builder(context).apply(builder)
            return builder.build()
        }
    }

    class Builder(context: Context) {
        private val context = context.applicationContext
        var retrievalMethods: List<DeviceRetrievalMethod>? = null

        fun retrievalMethods(retrievalMethods: List<DeviceRetrievalMethod>) =
            apply { this.retrievalMethods = retrievalMethods }

        fun build(): TransferManagerImpl {
            return TransferManagerImpl(
                context = context,
                retrievalMethods = retrievalMethods ?: emptyList()
            )
        }
    }
}
