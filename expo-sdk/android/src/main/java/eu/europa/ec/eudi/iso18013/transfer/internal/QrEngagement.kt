/*
 * Copyright (c) 2023-2024 European Commission
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package eu.europa.ec.eudi.iso18013.transfer.internal

import android.content.Context
import android.util.Log
import com.android.identity.android.mdoc.deviceretrieval.DeviceRetrievalHelper
import com.android.identity.android.mdoc.engagement.QrEngagementHelper
import com.android.identity.android.mdoc.transport.DataTransport
import eu.europa.ec.eudi.iso18013.transfer.engagement.DeviceRetrievalMethod
import org.multipaz.crypto.Crypto
import org.multipaz.crypto.EcCurve
import org.multipaz.crypto.EcPublicKey

internal class QrEngagement(
    private val context: Context,
    val retrievalMethods: List<DeviceRetrievalMethod>,
    val onConnecting: () -> Unit,
    val onQrEngagementReady: (qrCode: String) -> Unit,
    val onDeviceRetrievalHelperReady: (deviceRetrievalHelper: DeviceRetrievalHelper) -> Unit,
    val onNewDeviceRequest: (request: ByteArray) -> Unit,
    val onDisconnected: (transportSpecificTermination: Boolean) -> Unit,
    val onCommunicationError: (error: Throwable) -> Unit,
) {

    @JvmSynthetic
    internal var deviceRetrievalHelper: DeviceRetrievalHelper? = null

    @get:JvmSynthetic
    internal val eDevicePrivateKey by lazy {
        Crypto.createEcPrivateKey(EcCurve.P256)
    }

    @get:JvmSynthetic
    internal val qrEngagementListener = object : QrEngagementHelper.Listener {

        override fun onDeviceConnecting() {
            Log.d(this.TAG, "QR Engagement: Device Connecting")
            onConnecting()
        }

        override fun onDeviceConnected(transport: DataTransport) {
            if (deviceRetrievalHelper != null) {
                Log.d(
                    this.TAG,
                    "OnDeviceConnected for QR engagement -> ignoring due to active presentation"
                )
                return
            }

            Log.d(this.TAG, "OnDeviceConnected via QR: qrEngagement=$helper")

            val builder = DeviceRetrievalHelper.Builder(
                context,
                deviceRetrievalHelperListener,
                context.mainExecutor(),
                eDevicePrivateKey,
            )
            builder.useForwardEngagement(
                transport,
                helper.deviceEngagement,
                helper.handover,
            )
            deviceRetrievalHelper = builder.build()
            helper.close()
            onDeviceRetrievalHelperReady(requireNotNull(deviceRetrievalHelper))
        }

        override fun onError(error: Throwable) {
            Log.d(this.TAG, "QR onError: ${error.message}")
            onCommunicationError(error)
        }
    }

    @JvmSynthetic
    internal val deviceRetrievalHelperListener = object : DeviceRetrievalHelper.Listener {
        override fun onEReaderKeyReceived(eReaderKey: EcPublicKey) {
            Log.d(this.TAG, "DeviceRetrievalHelper Listener (QR): OnEReaderKeyReceived")
        }

        override fun onDeviceRequest(deviceRequestBytes: ByteArray) {
            Log.d(this.TAG, "DeviceRetrievalHelper Listener (QR): OnDeviceRequest")
            onNewDeviceRequest(deviceRequestBytes)
        }

        override fun onDeviceDisconnected(transportSpecificTermination: Boolean) {
            Log.d(this.TAG, "DeviceRetrievalHelper Listener (QR): onDeviceDisconnected")
            onDisconnected(transportSpecificTermination)
        }

        override fun onError(error: Throwable) {
            Log.d(this.TAG, "DeviceRetrievalHelper Listener (QR): onError -> ${error.message}")
            onCommunicationError(error)
        }
    }

    @JvmSynthetic
    internal lateinit var helper: QrEngagementHelper

    val deviceEngagementUriEncoded: String
        get() = helper.deviceEngagementUriEncoded

    /**
     * Configures the QR engagement
     */
    fun configure() {
        helper = QrEngagementHelper.Builder(
            context,
            eDevicePrivateKey.publicKey,
            retrievalMethods.transportOptions,
            qrEngagementListener,
            context.mainExecutor(),
        ).setConnectionMethods(retrievalMethods.connectionMethods)
            .build()
        onQrEngagementReady(helper.deviceEngagementUriEncoded)
    }

    /**
     * Closes the connection with the mdoc verifier
     */
    fun close() {
        try {
            helper.close()
        } catch (exception: RuntimeException) {
            Log.e(this.TAG, "Error closing QR engagement", exception)
        }
    }
}
