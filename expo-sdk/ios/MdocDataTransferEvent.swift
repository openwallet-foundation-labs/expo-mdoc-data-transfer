
enum MdocDataTransferEvent {
    case ON_REQUEST_RECEIVED
    case ON_RESPONSE_SENT
    case ON_ERROR

    var description : String {
        switch self {
        case .ON_REQUEST_RECEIVED: "onRequestReceived"
        case .ON_RESPONSE_SENT: "onResponseSent"
        case .ON_ERROR: "onError"
        }
    }
}
