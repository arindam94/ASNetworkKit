//
//  URLRequestBuilder.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

enum URLRequestBuilder {
    static func build(
        _ url: URLConvertible,
        method: HTTPMethod,
        parameters: [String: Any]?,
        urlEncoding: URLEncoding,
        headers: HTTPHeaders
    ) throws -> URLRequest {
        let url = try url.asURL()
        var req: URLRequest
        switch urlEncoding.destination {
        case .methodDependent:
            if method == .get || method == .head || method == .delete {
                let composed = try appendQuery(to: url, parameters: parameters)
                req = URLRequest(url: composed)
            } else {
                req = URLRequest(url: url)
                if let parameters { req.httpBody = query(parameters).data(using: .utf8) }
                req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            }
        case .queryString:
            let composed = try appendQuery(to: url, parameters: parameters)
            req = URLRequest(url: composed)
        case .httpBody:
            req = URLRequest(url: url)
            if let parameters { req.httpBody = query(parameters).data(using: .utf-8) }
            req.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        req.httpMethod = method.rawValue
        for (k,v) in headers.storage { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }
    
    static func build(
        _ url: URLConvertible,
        method: HTTPMethod,
        parameters: [String: Any]?,
        jsonEncoding: JSONEncoding,
        headers: HTTPHeaders
    ) throws -> URLRequest {
        let url = try url.asURL()
        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        if let parameters {
            req.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
            req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        for (k,v) in headers.storage { req.setValue(v, forHTTPHeaderField: k) }
        return req
    }
    
    private static func appendQuery(to url: URL, parameters: [String: Any]?) throws -> URL {
        guard let parameters, !parameters.isEmpty else { return url }
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) ?? URLComponents()
        var items = comps.queryItems ?? []
        items.append(contentsOf: parameters.flatMap { (key, value) -> [URLQueryItem] in
            if let arr = value as? [Any] {
                return arr.map { URLQueryItem(name: key, value: "\($0)") }
            }
            return [URLQueryItem(name: key, value: "\(value)")]
        })
        comps.queryItems = items
        guard let composed = comps.url else { throw NetworkError.invalidURL }
        return composed
    }
    
    private static func query(_ parameters: [String: Any]) -> String {
        parameters
            .sorted { $0.key < $1.key }
            .map { key, value in
                if let arr = value as? [Any] {
                    return arr.map { "\(escape(key))=\(escape(String(describing: $0)))" }.joined(separator: "&")
                } else {
                    return "\(escape(key))=\(escape(String(describing: value)))"
                }
            }
            .joined(separator: "&")
    }
    
    private static func escape(_ s: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }
}
