package id.animo.mdoc.proximity

import org.multipaz.mdoc.transport.NfcTransportMdoc

class Greeting {
    private val platform = getPlatform()

    fun greet(): String {
        return "Hello, ${platform.name}!"
    }
}
