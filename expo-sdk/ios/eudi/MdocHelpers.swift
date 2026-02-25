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

//  Helpers.swift
import Foundation
//import CoreBluetooth
//import Combine
import MdocDataModel18013
import MdocSecurity18013
//import AVFoundation
import SwiftCBOR
import Logging

/// Helper methods
public class MdocHelpers {
	
	static var errorNoDocumentsDescriptionKey: String { "doctype_not_found" }
	static func getErrorNoDocuments(_ docType: String) -> Error { NSError(domain: "\(MdocGattServer.self)", code: 0, userInfo: ["key": Self.errorNoDocumentsDescriptionKey, "%s": docType]) }
	
	public static func makeError(code: ErrorCode, str: String? = nil) -> NSError {
		let errorMessage = str ?? NSLocalizedString(code.description, comment: code.description)
		logger.error(Logger.Message(unicodeScalarLiteral: errorMessage))
		return NSError(domain: "\(MdocGattServer.self)", code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: errorMessage, "key": code.description])
	}
	
	/// Get the session data to send to the reader. The session data is encrypted using the session encryption object
	/// - Parameters:
	///   - sessionEncryption: Instance of session encryption object
	///   - status: Transfer status
	///   - docToSend: Device response object to send
	///
	/// - Returns: A tuple containing the encrypted session data and the clear text data to send.
	public static func getSessionDataToSend(sessionEncryption: SessionEncryption?, status: TransferStatus, docToSend: DeviceResponse) async -> Result<(Data, Data), Error> {
		do {
			guard var sessionEncryption else { logger.error("Session Encryption not initialized"); return .failure(Self.makeError(code: .sessionEncryptionNotInitialized)) }
			if docToSend.documents == nil, status != .error { logger.error("Could not create documents to send") }
			let cborToSend = docToSend.toCBOR(options: CBOROptions())
			let clearBytesToSend = cborToSend.encode()
			let cipherData = try await sessionEncryption.encrypt(clearBytesToSend)
			let sd = SessionData(cipher_data: status == .error ? nil : cipherData, status: status == .error ? 11 : 20)
			return .success((Data(sd.encode(options: CBOROptions())), Data(clearBytesToSend)))
		} catch { return .failure(error) }
	}
	
	/// Creates a block for a given block id from a data object. The block size is limited to maxBlockSize bytes.
	/// - Parameters:
	///   - data: The data object to be sent
	///   - blockId: The id (number) of the block to be sent
	///   - maxBlockSize: The maximum block size
	/// - Returns: (chunk:The data block, bEnd: True if this is the last block, false otherwise)
	public static func CreateBlockCommand(data: Data, blockId: Int, maxBlockSize: Int) -> (Data, Bool) {
		let start = blockId * maxBlockSize
		var end = (blockId+1) * maxBlockSize
		var bEnd = false
		if end >= data.count {
			end = data.count
			bEnd = true
		}
		let chunk = data.subdata(in: start..<end)
		return (chunk,bEnd)
	}
	
	/// Returns the number of blocks that dataLength bytes of data can be split into, given a maximum block size of maxBlockSize bytes.
	/// - Parameters:
	///   - dataLength: Length of data to be split
	///   - maxBlockSize: The maximum block size
	/// - Returns: Number of blocks
	public static func CountNumBlocks(dataLength: Int, maxBlockSize: Int) -> Int {
		let blockSize = maxBlockSize
		var numBlocks = 0
		if dataLength > maxBlockSize {
			numBlocks = dataLength / blockSize;
			if numBlocks * blockSize < dataLength {
				numBlocks += 1
			}
		} else if dataLength > 0 {
			numBlocks = 1
		}
		return numBlocks
	}
    
    public static func decodeDeviceRequestIntoSessionTranscript(_ deviceEngagement: DeviceEngagement, _ handOver: CBOR, _ sessionEstablishmentBytes: Data) async throws -> (Data, SessionEncryption) {
            guard let seCbor = try CBOR.decode([UInt8](sessionEstablishmentBytes)) else { logger.error("Request Data is not Cbor"); throw Self.makeError(code: .requestDecodeError) }
            let se = try SessionEstablishment(cbor: seCbor)
            let sessionEncryption = SessionEncryption(se: se, de: deviceEngagement, handOver: handOver)
            guard var sessionEncryption else { logger.error("Session Encryption not initialized"); throw Self.makeError(code: .sessionEncryptionNotInitialized) }
            let requestData = try await sessionEncryption.decrypt(se.data)
            let deviceRequest = try DeviceRequest(data: requestData)
            return (Data(deviceRequest.encode(options: CBOROptions())), sessionEncryption)
    }
    
    public static func encryptDeviceResponse(_ deviceResponseBytes: Data, _ sessionEncryption: SessionEncryption) async throws -> Data? {
        var se = sessionEncryption
        let cipherData = try await se.encrypt([UInt8](deviceResponseBytes))
        guard let cipherData else { return nil }
        let sd = SessionData(cipher_data: cipherData, status: 20)
        return Data(sd.encode(options: CBOROptions()))
    }
}
