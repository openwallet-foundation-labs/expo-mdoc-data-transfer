export enum MdocDataTransferEvent {
  OnRequestReceived = 'onRequestReceived',
  OnResponseSent = 'onResponseSent',
  OnError = 'onError',
}

export type OnResponseSentPayload = null

export type OnRequestReceivedEventPayload = {
  deviceRequest: string
  sessionTranscript: string
}

export type OnErrorPayload = {
  error: string
}
