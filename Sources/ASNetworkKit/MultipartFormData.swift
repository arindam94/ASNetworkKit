//
//  MultipartFormData.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

public final class MultipartFormData {
    public struct Part {
        let headers: [String: String]
        let data: Data
    }
    
    private var parts: [Part] = []
    
    public init(build: ((MultipartFormData) -> Void)? = nil) {
        if let build { build(self) }
    }
    
    public func append(_ data: Data, name: String, fileName: String? = nil, mimeType: String? = nil) {
        var headers = ["Content-Disposition": "form-data; name=\"\(name)\""]
        if let fileName {
            headers["Content-Disposition"] = "form-data; name=\"\(name)\"; filename=\"\(fileName)\""
        }
        if let mimeType {
            headers["Content-Type"] = mimeType
        }
        parts.append(Part(headers: headers, data: data))
    }
    
    public func append(_ string: String, name: String) {
        append(Data(string.utf8), name: name)
    }
    
    public func encode(boundary: String) -> Data {
        var body = Data()
        let boundaryLine = "--\(boundary)\r\n"
        for part in parts {
            body.append(boundaryLine.data(using: .utf8)!)
            for (k, v) in part.headers {
                body.append("\(k): \(v)\r\n".data(using: .utf8)!)
            }
            body.append("\r\n".data(using: .utf8)!)
            body.append(part.data)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
