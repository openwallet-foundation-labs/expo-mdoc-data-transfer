import { Buffer } from 'buffer'
import { MdocDataTransferError } from './MdocDataTransferError'
import {
  MdocDataTransferEvent,
  type OnErrorPayload,
  type OnRequestReceivedEventPayload,
  type OnResponseSentPayload,
} from './MdocDataTransferEvent'
import { NativeMdocDataTransfer } from './NativeMdocDataTransfer'

export let instance: MdocDataTransfer | undefined = undefined
export const mdocDataTransfer = {
  instance: () => {
    if (instance) return instance
    return MdocDataTransfer.initialize()
  },
  isInitialized: () => !!instance,
}

class MdocDataTransfer {
  public isNfcEnabled = false

  private static handleError(nativeCall: () => void) {
    let error: string | undefined
    const subscription = NativeMdocDataTransfer.addListener(
      MdocDataTransferEvent.OnError,
      (payload: OnErrorPayload) => {
        error = payload.error
      }
    )

    nativeCall()

    subscription.remove()

    if (error) {
      throw new MdocDataTransferError(error)
    }
  }

  public static initialize() {
    MdocDataTransfer.handleError(NativeMdocDataTransfer.initialize)

    instance = new MdocDataTransfer()
    return instance
  }

  public async startQrEngagement() {
    return await NativeMdocDataTransfer.startQrEngagement()
  }

  public async waitForDeviceRequest() {
    return await new Promise<{ deviceRequest: Uint8Array; sessionTranscript: Uint8Array }>((resolve) =>
      NativeMdocDataTransfer.addListener(
        MdocDataTransferEvent.OnRequestReceived,
        (payload: OnRequestReceivedEventPayload) => {
          resolve({
            deviceRequest: new Uint8Array(Buffer.from(payload.deviceRequest, 'base64')),
            sessionTranscript: new Uint8Array(Buffer.from(payload.sessionTranscript, 'base64')),
          })
        }
      )
    )
  }

  public async sendDeviceResponse(deviceResponse: Uint8Array) {
    const p = new Promise<OnResponseSentPayload>((resolve) =>
      NativeMdocDataTransfer.addListener(MdocDataTransferEvent.OnResponseSent, resolve)
    )

    MdocDataTransfer.handleError(() =>
      NativeMdocDataTransfer.sendDeviceResponse(Buffer.from(deviceResponse).toString('base64'))
    )

    await p
  }

  public shutdown() {
    this.isNfcEnabled = false
    MdocDataTransfer.handleError(NativeMdocDataTransfer.shutdown)
    instance = undefined
  }

  public enableNfc() {
    if (this.isNfcEnabled) return
    NativeMdocDataTransfer.enableNfc()
    this.isNfcEnabled = true
  }
}
