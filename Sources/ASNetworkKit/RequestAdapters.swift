//
//  RequestAdapters.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

public struct BearerTokenAdapter: RequestAdapter {
    private let tokenProvider: () -> String?
    public init(tokenProvider: @escaping () -> String?) { self.tokenProvider = tokenProvider }
    public func adapt(_ request: URLRequest) throws -> URLRequest {
        var req = request
        if let token = tokenProvider() {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }
}

public struct DefaultHeadersAdapter: RequestAdapter {
    private let headers: HTTPHeaders
    public init(_ headers: HTTPHeaders) { self.headers = headers }
    public func adapt(_ request: URLRequest) throws -> URLRequest {
        var req = request
        for (k, v) in headers.storage { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }
}
