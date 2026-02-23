import { NativeModule, requireNativeModule } from 'expo-modules-core'
import type { OnErrorPayload, OnRequestReceivedEventPayload, OnResponseSentPayload } from './MdocDataTransferEvent'

export type MdocDataTransferEvents = {
  onRequestReceived: (payload: OnRequestReceivedEventPayload) => void
  onResponseSent: (payload: OnResponseSentPayload) => void
  onError: (payload: OnErrorPayload) => void
}

declare class MdocDataTransferModule extends NativeModule<MdocDataTransferEvents> {
  initialize: () => void
  startQrEngagement: () => Promise<string>
  sendDeviceResponse: (devceResponse: string) => void
  shutdown: () => void
  enableNfc: () => void
}

export const NativeMdocDataTransfer = requireNativeModule<MdocDataTransferModule>('MdocDataTransfer')
