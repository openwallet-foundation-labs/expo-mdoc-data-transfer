package id.animo.mdocdatatransfer

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import id.animo.mdoc.proximity.Logic

class MdocDataTransferModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("MdocDataTransfer")
        Function("hello") {
          return@Function Logic().greet()
        }
    }
}
