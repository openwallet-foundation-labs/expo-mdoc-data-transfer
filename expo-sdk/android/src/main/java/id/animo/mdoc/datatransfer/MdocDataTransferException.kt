package foundation.openwallet.mdoc.datatransfer

import expo.modules.kotlin.exception.CodedException

class MdocDataTransferException {
    class NotInitialized : Exception("MdocDataTransfer class was not initialized")

    /** Extends [CodedException] so it can be handed to `Promise.reject` with an inferred error code. */
    class EngagementFailed(cause: Throwable) : CodedException(
        message = "Could not start the device engagement: ${cause.message ?: cause.toString()}",
        cause = cause
    )
}
