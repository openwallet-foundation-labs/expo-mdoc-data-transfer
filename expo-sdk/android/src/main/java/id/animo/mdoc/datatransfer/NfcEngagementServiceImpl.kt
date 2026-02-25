package foundation.openwallet.mdoc.datatransfer

import eu.europa.ec.eudi.iso18013.transfer.TransferManager
import eu.europa.ec.eudi.iso18013.transfer.engagement.NfcEngagementService

class NfcEngagementServiceImpl : NfcEngagementService() {
    override val transferManager: TransferManager get() = MdocDataTransferManager.transferManager.value
}
