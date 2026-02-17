//
//  ShareXServerConfig.swift
//  DropUploader
//
//  Created by Miles on 2/17/26.
//


struct ShareXServerConfig: Codable, Equatable {
    let Version: String?
    let Name: String?
    let DestinationType: String?

    let RequestMethod: String?
    let RequestURL: String

    let Headers: [String: String]?
    let Arguments: [String: String?]?
    let Body: String?
    let FileFormName: String?

    let URL: String?

    var method: String { (RequestMethod ?? "POST").uppercased() }
    var fileFormName: String { FileFormName ?? "file" }

    var nonNullArguments: [String: String] {
        (Arguments ?? [:]).compactMapValues { $0 }
    }

    var headers: [String: String] {
        Headers ?? [:]
    }
}
