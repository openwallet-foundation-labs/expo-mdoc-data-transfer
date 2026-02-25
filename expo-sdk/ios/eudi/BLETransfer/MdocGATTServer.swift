/*
Copyright (c) 2023 European Commission

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import Foundation
import SwiftCBOR
import CoreBluetooth
import Logging
import MdocDataModel18013
import MdocSecurity18013
import WalletStorage

public class MdocGattServer: @unchecked Sendable, ObservableObject {
	var secureArea: SecureEnclaveSecureArea!
	var crv = CoseEcCurve.P256
	
	var peripheralManager: CBPeripheralManager!
	var bleDelegate: Delegate!
	var remoteCentral: CBCentral!
	var stateCharacteristic: CBMutableCharacteristic!
	var server2ClientCharacteristic: CBMutableCharacteristic!
	var deviceEngagement: DeviceEngagement?
    var sessionEncryption: SessionEncryption?
	var qrCodePayload: String?
	public var delegate: any MdocOfflineDelegate
	var continuationQrCodeReady: CheckedContinuation<Void, Error>?
	public var advertising: Bool = false
	public var error: Error? = nil {
		willSet {
			handleErrorSet(newValue)
		}
	}
	public var status: TransferStatus = .initializing {
		willSet {
			Task { @MainActor in
				await handleStatusChange(newValue)
			}
		}
	}
	public var unlockData: [String: Data]!
    
	var readBuffer = Data()
	var sendBuffer = [Data]()
	var numBlocks: Int = 0
	var subscribeCount: Int = 0
	var initSuccess:Bool = false

    public init(_ delegate: any MdocOfflineDelegate)  {
		secureArea = SecureEnclaveSecureArea.create(storage: KeyChainSecureKeyStorage(serviceName: "MDOC_PROXIMITY_SERVICE", accessGroup: nil))
		status = .initialized
        self.delegate = delegate
		initPeripheralManager()
		initSuccess = true
	}

	@objc(CBPeripheralManagerDelegate)
	class Delegate: NSObject, CBPeripheralManagerDelegate {
		unowned var server: MdocGattServer

		init(server: MdocGattServer) {
			self.server = server
		}

		func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
			if server.sendBuffer.count > 0 {
				self.server.sendDataWithUpdates()
			}
		}

		func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
			logger.info("CBPeripheralManager didUpdateState:")
			logger.info(peripheral.state == .poweredOn ? "Powered on" : peripheral.state == .unauthorized ? "Unauthorized" : peripheral.state == .unsupported ? "Unsupported" : "Powered off")
			if peripheral.state == .poweredOn, server.qrCodePayload != nil {
				server.continuationQrCodeReady?.resume()
				server.continuationQrCodeReady = nil
			}
		}

		func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
			if requests[0].characteristic.uuid == MdocServiceCharacteristic.state.uuid, let h = requests[0].value?.first {
				if h == BleTransferMode.START_REQUEST.first! {
					logger.info("Start request received to state characteristic") // --> start
					server.status = .started
					server.readBuffer.removeAll()
				} else if h == BleTransferMode.END_REQUEST.first! {
					guard server.status == .responseSent else {
						logger.error("State END command rejected. Not in responseSent state")
						peripheral.respond(to: requests[0], withResult: .unlikelyError)
						return
					}
					logger.info("End received to state characteristic") // --> end
					server.status = .disconnected
				}
			} else if requests[0].characteristic.uuid == MdocServiceCharacteristic.client2Server.uuid {
				for r in requests {
					guard let data = r.value, let h = data.first else {
						continue
					}
					let bStart = h == BleTransferMode.START_DATA.first!
					let bEnd = (h == BleTransferMode.END_DATA.first!)
					if data.count > 1 {
						server.readBuffer.append(data.advanced(by: 1))
					}
					if !bStart && !bEnd {
						logger.warning("Not a valid request block: \(data)")
					}
					if bEnd {
						server.status = .requestReceived
					}
				}
			}
			peripheral.respond(to: requests[0], withResult: .success)
		}

		public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
			guard server.status == .qrEngagementReady else {
				return
			}
			let mdocCbc = MdocServiceCharacteristic(uuid: characteristic.uuid)
			logger.info("Remote central \(central.identifier) connected for \(mdocCbc?.rawValue ?? "") characteristic")
			server.remoteCentral = central
			if characteristic.uuid == MdocServiceCharacteristic.state.uuid || characteristic.uuid == MdocServiceCharacteristic.server2Client.uuid {
				server.subscribeCount += 1
			}
			if server.subscribeCount > 1 {
				server.status = .connected
			}
		}

		public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
			let mdocCbc = MdocServiceCharacteristic(uuid: characteristic.uuid)
			logger.info("Remote central \(central.identifier) disconnected for \(mdocCbc?.rawValue ?? "") characteristic")
		}
	}

	/// Returns true if the peripheralManager state is poweredOn
	public var isBlePoweredOn: Bool { peripheralManager.state == .poweredOn }

	/// Returns true if the peripheralManager state is unauthorized
	public var isBlePermissionDenied: Bool { peripheralManager.state == .unauthorized }

	// Create a new device engagement object and start the device engagement process.
	///
	/// ``qrCodePayload`` is set to QR code data corresponding to the device engagement.
	public func performDeviceEngagement() async throws -> String {
		guard status == .initialized || status == .disconnected || status == .responseSent else {
			throw MdocHelpers.makeError(code: .unexpected_error, str: error?.localizedDescription ?? "Not initialized!")
		}
		deviceEngagement = DeviceEngagement(isBleServer: true, rfus: nil)
		try await deviceEngagement!.makePrivateKey(crv: crv, secureArea: secureArea)
		qrCodePayload = deviceEngagement!.getQrCodePayload()
		guard peripheralManager.state != .unauthorized else {
			throw MdocHelpers.makeError(code: .bleNotAuthorized)
		}
		if !isBlePoweredOn {
			try await withCheckedThrowingContinuation { c in
				continuationQrCodeReady = c
			}
		}
		startBleAdvertising()
		return qrCodePayload!
	}

	func buildServices(uuid: String) {
		let bleUserService = CBMutableService(type: CBUUID(string: uuid), primary: true)
		stateCharacteristic = CBMutableCharacteristic(type: MdocServiceCharacteristic.state.uuid, properties: [.notify, .writeWithoutResponse], value: nil, permissions: [.writeable])
		let client2ServerCharacteristic = CBMutableCharacteristic(type: MdocServiceCharacteristic.client2Server.uuid, properties: [.writeWithoutResponse], value: nil, permissions: [.writeable])
		server2ClientCharacteristic = CBMutableCharacteristic(type: MdocServiceCharacteristic.server2Client.uuid, properties: [.notify], value: nil, permissions: [])
		bleUserService.characteristics = [stateCharacteristic, client2ServerCharacteristic, server2ClientCharacteristic]
		peripheralManager.removeAllServices()
		peripheralManager.add(bleUserService)
	}

	func startBleAdvertising() {
		guard !isPreview && !isInErrorState else {
			logger.info("Current status is \(status)")
			return
		}
		if peripheralManager.state == .poweredOn {
			logger.info("Peripheral manager powered on")
			error = nil
			guard let uuid = deviceEngagement?.ble_uuid else {
				logger.error("BLE initialization error")
				return
			}
			buildServices(uuid: uuid)
			let advertisementData: [String: Any] = [ CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: uuid)], CBAdvertisementDataLocalNameKey: uuid ]
			// advertise the peripheral with the short UUID
			peripheralManager.startAdvertising(advertisementData)
			advertising = true
			status = .qrEngagementReady
		} else {
		// once bt is powered on, advertise
		if peripheralManager.state == .resetting {
			DispatchQueue.main.asyncAfter(deadline: .now()+1) {
				self.startBleAdvertising()
			}
		} else {
			logger.info("Peripheral manager powered off")
		}
		}
	}

	public func stop() {
		guard !isPreview else {
			return
		}
		if let peripheralManager, peripheralManager.isAdvertising {
			peripheralManager.stopAdvertising()
		}
		qrCodePayload = nil
		advertising = false
		subscribeCount = 0
		if let pk = deviceEngagement?.privateKey {
			Task { @MainActor in
				try? await pk.secureArea.deleteKeyBatch(id: pk.privateKeyId, startIndex: 0, batchSize: 1)
				deviceEngagement?.privateKey = nil
			}
		}
		if status == .error && initSuccess {
			status = .initializing
		}
	}

	fileprivate func initPeripheralManager() {
		guard peripheralManager == nil else {
			return
		}
		bleDelegate = Delegate(server: self)
		logger.info("Initializing BLE peripheral manager")
		peripheralManager = CBPeripheralManager(delegate: bleDelegate, queue: nil)
		subscribeCount = 0
	}

	func handleStatusChange(_ newValue: TransferStatus) async {
        do {
            guard !isPreview && !isInErrorState else {
                return
            }
            guard let deviceEngagement else {
                return
            }
            logger.log(level: .info, "Transfer status will change to \(newValue)")
            delegate.didChangeStatus(newValue)
            if newValue == .requestReceived {
                peripheralManager.stopAdvertising()
                let (dr, se) = try await MdocHelpers.decodeDeviceRequestIntoSessionTranscript(deviceEngagement, BleTransferMode.QRHandover, readBuffer)
                sessionEncryption = se
                delegate.didReceiveRequest(dr, Data(se.sessionTranscriptBytes))
            }
            else if newValue == .initialized {
                initPeripheralManager()
            } else if newValue == .disconnected && status != .disconnected {
                stop()
            }
        } catch {
            logger.log(level: .error, "\(error.localizedDescription)")
        }
	}

	var isPreview: Bool {
		ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
	}

	var isInErrorState: Bool { status == .error }

	func handleErrorSet(_ newValue: Error?) {
		guard let newValue else {
			return
		}
		status = .error
		delegate.didFinishedWithError(newValue)
		logger.log(level: .error, "Transfer error \(newValue) (\(newValue.localizedDescription)")
	}

	func prepareDataToSend(_ msg: Data) {
		let mbs = min(511, remoteCentral.maximumUpdateValueLength-1)
		numBlocks = MdocHelpers.CountNumBlocks(dataLength: msg.count, maxBlockSize: mbs)
		logger.info("Sending response of total bytes \(msg.count) in \(numBlocks) blocks and block size: \(mbs)")
		sendBuffer.removeAll()
		// send blocks
		for i in 0..<numBlocks {
			let (block,bEnd) = MdocHelpers.CreateBlockCommand(data: msg, blockId: i, maxBlockSize: mbs)
			var blockWithHeader = Data()
			blockWithHeader.append(contentsOf: !bEnd ? BleTransferMode.START_DATA : BleTransferMode.END_DATA)
			// send actual data after header
			blockWithHeader.append(contentsOf: block)
			sendBuffer.append(blockWithHeader)
		}
	}

	func sendDataWithUpdates() {
		guard !isPreview else {
			return
		}
		guard sendBuffer.count > 0 else {
			status = .responseSent
			logger.info("Finished sending BLE data")
			stop()
			return
		}
		let b = peripheralManager.updateValue(sendBuffer.first!, for: server2ClientCharacteristic, onSubscribedCentrals: [remoteCentral])
		if b, sendBuffer.count > 0 {
			sendBuffer.removeFirst()
			sendDataWithUpdates()
		}
	}
    
    func sendDeviceResponse(deviceResponse: Data) async throws {
        guard let sessionEncryption else { throw MdocHelpers.makeError(code: .unexpected_error, str: error?.localizedDescription ?? "session encryption not found") }
        let encryptedDeviceResponse = try await MdocHelpers.encryptDeviceResponse(deviceResponse, sessionEncryption)
        guard let encryptedDeviceResponse else { throw MdocHelpers.makeError(code: .unexpected_error, str: error?.localizedDescription ?? "Could not encrypt device response") }
        self.prepareDataToSend(encryptedDeviceResponse)
        self.sendDataWithUpdates()
    }
}

