//
//  ASNetworkKit.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", patch = "PATCH", delete = "DELETE", head = "HEAD"
}

public struct HTTPHeaders: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = String
    public private(set) var storage: [String: String] = [:]
    public init(_ dict: [String: String] = [:]) { self.storage = dict }
    public init(dictionaryLiteral elements: (String, String)...) {
        for (k, v) in elements { storage[k] = v }
    }
    public subscript(_ name: String) -> String? {
        get { storage[name] }
        set { storage[name] = newValue }
    }
    public mutating func add(name: String, value: String) { storage[name] = value }
}

public enum ParameterEncoding {
    case url(URLEncoding = .default)
    case json(JSONEncoding = .default)
}

public struct URLEncoding {
    public enum Destination { case methodDependent, queryString, httpBody }
    public static let `default` = URLEncoding()
    public var destination: Destination = .methodDependent
    public init(destination: Destination = .methodDependent) { self.destination = destination }
}

public struct JSONEncoding {
    public static let `default` = JSONEncoding()
    public init() {}
}

public enum NetworkError: Error, CustomStringConvertible {
    case invalidURL
    case requestAdaptationFailed(Error)
    case serializationFailed(Error)
    case serverError(statusCode: Int, data: Data?)
    case underlying(Error)
    case cancelled
    public var description: String {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestAdaptationFailed(let e): return "Request adaptation failed: \(e)"
        case .serializationFailed(let e): return "Serialization failed: \(e)"
        case .serverError(let code, _): return "Server error with status code \(code)"
        case .underlying(let e): return "Underlying error: \(e)"
        case .cancelled: return "Cancelled"
        }
    }
}

public protocol RequestAdapter {
    func adapt(_ request: URLRequest) throws -> URLRequest
}

public protocol RequestRetrier {
    func retry(_ request: URLRequest, dueTo error: Error, attempt: Int) async -> Bool
}

public final class ExponentialBackoffRetrier: RequestRetrier {
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    public init(maxRetries: Int = 2, baseDelay: TimeInterval = 0.6) {
        self.maxRetries = maxRetries; self.baseDelay = baseDelay
    }
    public func retry(_ request: URLRequest, dueTo error: Error, attempt: Int) async -> Bool {
        guard attempt < maxRetries else { return false }
        let delay = pow(2.0, Double(attempt)) * baseDelay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return true
    }
}

public struct Validation {
    public var acceptableStatusCodes: Range<Int> = 200..<300
    public var acceptableContentTypes: [String]? = nil
    public init(acceptableStatusCodes: Range<Int> = 200..<300, acceptableContentTypes: [String]? = nil) {
        self.acceptableStatusCodes = acceptableStatusCodes
        self.acceptableContentTypes = acceptableContentTypes
    }
}

public final class Session {
    public static let `default` = Session()
    public let configuration: URLSessionConfiguration
    public let session: URLSession
    public var adapters: [RequestAdapter] = []
    public var retrier: RequestRetrier? = ExponentialBackoffRetrier()
    
    public init(configuration: URLSessionConfiguration = .default, delegateQueue: OperationQueue? = nil) {
        self.configuration = configuration
        self.session = URLSession(configuration: configuration, delegate: nil, delegateQueue: delegateQueue)
    }
    
    // MARK: Request
    
    public func request(
        _ url: URLConvertible,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil,
        encoding: URLEncoding = .default,
        headers: HTTPHeaders = [:]
    ) -> DataRequest {
        var req: URLRequest
        do {
            req = try URLRequestBuilder.build(url, method: method, parameters: parameters, urlEncoding: encoding, headers: headers)
            req = try applyAdapters(req)
        } catch {
            return DataRequest(session: session, request: nil, error: error, retrier: retrier)
        }
        return DataRequest(session: session, request: req, retrier: retrier)
    }
    
    public func request(
        _ url: URLConvertible,
        method: HTTPMethod = .post,
        parameters: [String: Any]? = nil,
        jsonEncoding: JSONEncoding = .default,
        headers: HTTPHeaders = [:]
    ) -> DataRequest {
        var req: URLRequest
        do {
            req = try URLRequestBuilder.build(url, method: method, parameters: parameters, jsonEncoding: jsonEncoding, headers: headers)
            req = try applyAdapters(req)
        } catch {
            return DataRequest(session: session, request: nil, error: error, retrier: retrier)
        }
        return DataRequest(session: session, request: req, retrier: retrier)
    }
    
    // Upload
    public func upload(_ data: Data, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders = [:]) -> DataRequest {
        var req: URLRequest
        do {
            req = try URLRequestBuilder.build(url, method: method, parameters: nil, urlEncoding: .default, headers: headers)
            req.httpBody = data
            req.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
            req = try applyAdapters(req)
        } catch {
            return DataRequest(session: session, request: nil, error: error, retrier: retrier)
        }
        return DataRequest(session: session, request: req, retrier: retrier)
    }
    
    public func upload(multipart: MultipartFormData, to url: URLConvertible, method: HTTPMethod = .post, headers: HTTPHeaders = [:]) -> DataRequest {
        var req: URLRequest
        do {
            let boundary = "asnk-\(UUID().uuidString)"
            var mutableHeaders = headers
            mutableHeaders.add(name: "Content-Type", value: "multipart/form-data; boundary=\(boundary)")
            req = try URLRequestBuilder.build(url, method: method, parameters: nil, urlEncoding: .default, headers: mutableHeaders)
            req.httpBody = multipart.encode(boundary: boundary)
            req = try applyAdapters(req)
        } catch {
            return DataRequest(session: session, request: nil, error: error, retrier: retrier)
        }
        return DataRequest(session: session, request: req, retrier: retrier)
    }
    
    // Download
    public func download(_ url: URLConvertible, to destinationURL: URL) -> DownloadRequest {
        do {
            let url = try url.asURL()
            return DownloadRequest(session: session, url: url, destination: destinationURL)
        } catch {
            return DownloadRequest(session: session, url: URL(string: "about:blank")!, destination: destinationURL, error: error)
        }
    }
    
    private func applyAdapters(_ request: URLRequest) throws -> URLRequest {
        var req = request
        for adapter in adapters {
            req = try adapter.adapt(req)
        }
        return req
    }
}

public protocol URLConvertible {
    func asURL() throws -> URL
}

extension String: URLConvertible {
    public func asURL() throws -> URL {
        guard let url = URL(string: self) else { throw NetworkError.invalidURL }
        return url
    }
}

extension URL: URLConvertible {
    public func asURL() throws -> URL { self }
}
