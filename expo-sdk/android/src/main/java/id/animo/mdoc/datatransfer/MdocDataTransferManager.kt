package id.animo.mdoc.datatransfer

import android.annotation.SuppressLint
import android.content.Context
import eu.europa.ec.eudi.iso18013.transfer.TransferManager
import eu.europa.ec.eudi.iso18013.transfer.engagement.BleRetrievalMethod

@SuppressLint("StaticFieldLeak")
object MdocDataTransferManager {
    @Volatile
    private lateinit var context: Context

    fun init(context: Context) {
        this.context = context
    }

    val transferManager = lazy {
        TransferManager.getDefault(
            context,
            listOf(
                BleRetrievalMethod(
                    peripheralServerMode = true,
                    centralClientMode = true,
                    clearBleCache = true
                )
            )
        )

    }
}
