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
import android.util.Base64
import android.util.Log
import androidx.core.net.toUri
import com.android.identity.android.mdoc.deviceretrieval.DeviceRetrievalHelper
import com.android.identity.android.mdoc.transport.DataTransport
import com.android.identity.android.mdoc.transport.DataTransportOptions
import org.multipaz.cbor.Cbor
import org.multipaz.crypto.Crypto
import org.multipaz.crypto.EcCurve
import org.multipaz.crypto.EcPublicKey
import org.multipaz.mdoc.engagement.DeviceEngagement
import org.multipaz.mdoc.origininfo.OriginInfo

internal class EngagementToApp(
    private val context: Context,
    private val dataTransportOptions: DataTransportOptions,
    private val onPresentationReady: (deviceRetrievalHelper: DeviceRetrievalHelper) -> Unit,
    private val onNewRequest: (request: ByteArray) -> Unit,
    private val onDisconnected: () -> Unit,
    private val onCommunicationError: (error: Throwable) -> Unit,
) {

    @JvmSynthetic
    internal val eDevicePrivateKey = Crypto.createEcPrivateKey(EcCurve.P256)

    private val presentationListener = object : DeviceRetrievalHelper.Listener {
        override fun onEReaderKeyReceived(eReaderKey: EcPublicKey) {
            Log.d(TAG, "DeviceRetrievalHelper Listener (QR): OnEReaderKeyReceived")
        }

        override fun onDeviceRequest(deviceRequestBytes: ByteArray) {
            onNewRequest(deviceRequestBytes)
        }

        override fun onDeviceDisconnected(transportSpecificTermination: Boolean) {
            onDisconnected()
        }

        override fun onError(error: Throwable) {
            onCommunicationError(error)
        }
    }

    fun configure(
        reverseEngagementUri: String,
        origins: List<OriginInfo>,
    ) {
        val uri = reverseEngagementUri.toUri()
        check(uri.scheme.equals("mdoc")) { "Only supports mdoc URIs" }

        val encodedReaderEngagement = Base64.decode(
            uri.encodedSchemeSpecificPart,
            Base64.URL_SAFE or Base64.NO_PADDING,
        )
        val engagement = DeviceEngagement.fromDataItem(Cbor.decode(encodedReaderEngagement))
        check(engagement.connectionMethods.isNotEmpty()) { "No connection methods in engagement" }

        // For now, just pick the first transport
        val connectionMethod = engagement.connectionMethods[0]
        Log.d(this.TAG, "Using connection method $connectionMethod")

        val transport = DataTransport.fromConnectionMethod(
            context,
            connectionMethod,
            DataTransport.Role.MDOC,
            dataTransportOptions,
        )

        val builder = DeviceRetrievalHelper.Builder(
            context,
            presentationListener,
            context.mainExecutor(),
            eDevicePrivateKey,
        ).useReverseEngagement(transport, encodedReaderEngagement, origins)
        builder.build().apply {
            onPresentationReady(this)
        }
    }
}
