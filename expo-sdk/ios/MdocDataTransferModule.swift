import ExpoModulesCore
import MdocDataModel18013
import SwiftCBOR

public class MdocDataTransferModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MdocDataTransfer")
      
    let bleServerTransfer: MdocGattServer = MdocGattServer(self)
      
    Events(
        MdocDataTransferEvent.ON_REQUEST_RECEIVED.description,
        MdocDataTransferEvent.ON_RESPONSE_SENT.description
    )

    Function("initialize") {
        // no-op
    }
      
      AsyncFunction("startQrEngagement") {
          try await bleServerTransfer.performDeviceEngagement()
      }
      
      AsyncFunction("sendDeviceResponse") { (deviceResponse: String) in
        try await bleServerTransfer.sendDeviceResponse(deviceResponse: Data(base64Encoded: deviceResponse.data(using: .utf8)!)!)
        sendEvent(MdocDataTransferEvent.ON_RESPONSE_SENT.description)
    }
      
    Function("shutdown") {
        bleServerTransfer.stop()
    }
      
    Function("enableNfc") {
        // no-op
    }
  }
}

extension MdocDataTransferModule : MdocOfflineDelegate {
    public func didChangeStatus(_ newStatus: TransferStatus) {
        // no-op
    }
    
    public func didFinishedWithError(_ error: any Error) {
        // no-op
    }
    
    public func didReceiveRequest(_ deviceRequest: Data, _ sessionTranscript: Data) {
        do {
            let dr = try DeviceRequest(data: deviceRequest.bytes).encode(options: CBOROptions())
            sendEvent(MdocDataTransferEvent.ON_REQUEST_RECEIVED.description, ["deviceRequest": Data(dr).base64EncodedString(),"sessionTranscript": sessionTranscript.base64EncodedString() ])
        } catch {
            logger.error("\(error.localizedDescription)")
        }
    }
    
    
}
