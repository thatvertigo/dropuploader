//
//  ShareXServerConfig.swift
//  DropUploader
//
//  Created by Miles on 2/17/26.
//


struct ShareXServerConfig: Codable, Equatable {
    let Version: String?
    let DestinationType: String?
    let RequestMethod: String?
    let RequestURL: String
    let Body: String?
    let Arguments: [String: String?]?
    let FileFormName: String?

    var method: String { (RequestMethod ?? "POST").uppercased() }
    var fileFormName: String { FileFormName ?? "file" }
    var nonNullArguments: [String: String] {
        (Arguments ?? [:]).compactMapValues { $0 }
    }
}
