import MdocDataModel18013
import MdocDataTransfer18013
import MdocSecurity18013
import React
import SwiftCBOR

@objc(MdocDataTransfer)
class MdocDataTransfer: RCTEventEmitter {
    let ON_RESPONSE_SENT_EVENT: String = "onResponseSent"
    let ON_REQUEST_RECEIVED_EVENT: String = "onRequestReceived"
    let ON_ERROR_EVENT: String = "onError"

    var bleServerTransfer: MdocGattServer?
    var resolver: RCTPromiseResolveBlock?
    var rejector: RCTPromiseRejectBlock?

    override func supportedEvents() -> [String]! {
        return [ON_RESPONSE_SENT_EVENT, ON_REQUEST_RECEIVED_EVENT, ON_ERROR_EVENT]
    }

    // NFC is not enabled on iOS
    @objc
    func enableNfc() {
        return
    }

    @objc
    func initialize() {
        do {
            bleServerTransfer = try MdocGattServer(parameters: [
                InitializeKeys.document_json_data.rawValue: [],
                InitializeKeys.trusted_certificates.rawValue: [],
                InitializeKeys.send_response_manually.rawValue: true,
            ])
            bleServerTransfer?.delegate = self
        } catch {
            sendEvent(withName: ON_ERROR_EVENT, body: ["error": error.localizedDescription])
        }
    }

    @objc(startQrEngagement:_:)
    func startQrEngagement(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        resolver = resolve
        rejector = reject

        guard let bleServerTransfer = bleServerTransfer else {
            self.reject(
                MdocDataTransferError.BleGattServerNotInitialized
                    .localizedDescription)
            return
        }

        bleServerTransfer.performDeviceEngagement()
    }

    @objc(sendDeviceResponse:)
    func sendDeviceResponse(deviceResponse: String) {
        guard let bleServerTransfer = bleServerTransfer,
            var sessionEncryption = bleServerTransfer.sessionEncryption
        else {
            sendEvent(withName: ON_ERROR_EVENT, body: ["error": MdocDataTransferError.BleGattServerNotInitialized.localizedDescription])
            return
        }

        do {
            let byteArray = Data(base64Encoded: deviceResponse.data(using: .utf8)!)!
            
            let cipherData = try sessionEncryption.encrypt([UInt8](byteArray))
            let sd = SessionData(cipher_data: cipherData, status: 20)
            try bleServerTransfer.sendResponse(
                Data(sd.encode(options: CBOROptions())))
        } catch {
            let sd = SessionData(cipher_data: nil, status: 11)
            do {
                try bleServerTransfer.sendResponse(
                    Data(sd.encode(options: CBOROptions())))
            } catch {
                sendEvent(withName: ON_ERROR_EVENT, body:  ["error": error.localizedDescription])
                return
            }
            sendEvent(withName: ON_ERROR_EVENT, body:  ["error": error.localizedDescription])
        }
    }

    @objc
    func shutdown() {
        guard let bleServerTransfer = bleServerTransfer else {
            sendEvent(withName: ON_ERROR_EVENT, body: ["error": MdocDataTransferError.BleGattServerNotInitialized.localizedDescription])
            return

        }

        bleServerTransfer.stop()

        self.bleServerTransfer = nil
        rejector = nil
        resolver = nil
    }

    private func reject(_ message: String) {
        guard let rejector = rejector else {
            fatalError(
                MdocDataTransferError.RejectorNotInitialized
                    .localizedDescription)
        }
        rejector("ERROR", message, nil)

        resolver = nil
        self.rejector = nil
    }

    private func resolve(_ result: Any) {
        guard let resolver = resolver else {
            fatalError(
                MdocDataTransferError.ResolverNotInitialized
                    .localizedDescription)
        }
        resolver(result)

        self.resolver = nil
        rejector = nil
    }
}

extension MdocDataTransfer: MdocOfflineDelegate {
    public func didChangeStatus(
        _ newStatus: MdocDataTransfer18013.TransferStatus
    ) {
        guard let bleServerTransfer = bleServerTransfer else {
            reject(
                MdocDataTransferError.BleGattServerNotInitialized
                    .localizedDescription)
            return
        }

        switch newStatus {
        case .qrEngagementReady:
            guard let qrCode = bleServerTransfer.qrCodePayload else {
                reject(MdocDataTransferError.QrCodeNotSet.localizedDescription)
                return
            }
            resolve(qrCode)
        case .error:
            guard let error = bleServerTransfer.error else {
                reject(MdocDataTransferError.ErrorNotSet.localizedDescription)
                return
            }
            reject(error.localizedDescription)
            return
        case .responseSent:
            sendEvent(withName: ON_RESPONSE_SENT_EVENT, body: nil)
        default:
            os_log("data transfer status change: %@", newStatus.rawValue)
        }

    }

    public func didFinishedWithError(_ error: any Error) {
        sendEvent(withName: ON_ERROR_EVENT, body: ["error": error.localizedDescription])
    }

    public func didReceiveRequest(
        _ request: MdocDataTransfer18013.UserRequestInfo?,
        handleSelected: @escaping (Bool, MdocDataTransfer18013.RequestItems?) ->
            Void
    ) {
        guard
            let sessionTranscriptBytes = bleServerTransfer?.sessionEncryption?
                .sessionTranscriptBytes,
            let deviceRequestBytes = bleServerTransfer?.deviceRequest?.encode(
                options: CBOROptions())
        else {
            return
        }

        sendEvent(
            withName: ON_REQUEST_RECEIVED_EVENT,
            body: [
                "sessionTranscript": Data(sessionTranscriptBytes).base64EncodedString(),
                "deviceRequest": Data(deviceRequestBytes).base64EncodedString(),
            ])
    }
}
