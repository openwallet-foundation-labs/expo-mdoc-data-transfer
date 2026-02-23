import ExpoModulesCore

public class MdocDataTransferModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MdocDataTransfer")
      
    let bleServerTransfer: MdocGattServer = MdocGattServer()
      
    Events(
        MdocDataTransferEvent.ON_REQUEST_RECEIVED.description,
        MdocDataTransferEvent.ON_RESPONSE_SENT.description
    )

    Function("initialize") {
        // no-op
    }
      
      AsyncFunction("startQrEngagement") { (promise: Promise) in
          do {
              let qrCode = try await bleServerTransfer.performDeviceEngagement()
              promise.resolve(qrCode)
          } catch {
              promise.reject(error)
          }
      }
      
      Function("sendDeviceResponse") { (deviceResponse: String) in
        bleServerTransfer.sendDeviceResponse(deviceResponse: Data(base64Encoded: deviceResponse.data(using: .utf8)!)!)
    }
      
    Function("shutdown") {
        bleServerTransfer.stop()
    }
      
    Function("enableNfc") {
        // no-op
    }
  }
}
