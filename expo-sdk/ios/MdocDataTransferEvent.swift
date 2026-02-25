
enum MdocDataTransferEvent {
    case ON_REQUEST_RECEIVED
    case ON_RESPONSE_SENT

    var description : String {
        switch self {
        case .ON_REQUEST_RECEIVED: "onRequestReceived"
        case .ON_RESPONSE_SENT: "onResponseSent"
        }
    }
}
