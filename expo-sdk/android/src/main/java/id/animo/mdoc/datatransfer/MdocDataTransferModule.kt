package id.animo.mdoc.datatransfer

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import id.animo.mdoc.proximity.Greeting

class MdocDataTransferModule : Module() {
    override fun definition() = ModuleDefinition {
        Name("MdocDataTransfer")

        Function("hello") {
          return@Function Greeting().greet()
        }
    }
}
