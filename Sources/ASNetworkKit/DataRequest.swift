//
//  DataRequest.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

public final class DataRequest {
    private let session: URLSession
    private(set) var request: URLRequest?
    private let retrier: RequestRetrier?
    private var validation: Validation = Validation()
    private var task: URLSessionDataTask?
    private var attempt = 0
    private var storedError: Error?
    
    init(session: URLSession, request: URLRequest?, error: Error? = nil, retrier: RequestRetrier?) {
        self.session = session
        self.request = request
        self.retrier = retrier
        self.storedError = error
    }
    
    @discardableResult
    public func validate(statusCodes: Range<Int> = 200..<300, contentTypes: [String]? = nil) -> Self {
        validation = Validation(acceptableStatusCodes: statusCodes, acceptableContentTypes: contentTypes)
        return self
    }
    
    public func cancel() {
        task?.cancel()
    }
    
    // MARK: - Callback APIs
    
    public func responseData(completion: @escaping (Result<Data, Error>) -> Void) {
        execute { completion($0.map { $0.data }) }
    }
    
    public func responseString(encoding: String.Encoding = .utf8, completion: @escaping (Result<String, Error>) -> Void) {
        execute { res in
            switch res {
            case .success(let payload):
                let string = String(data: payload.data, encoding: encoding) ?? ""
                completion(.success(string))
            case .failure(let err): completion(.failure(err))
            }
        }
    }
    
    public func responseJSON(options: JSONSerialization.ReadingOptions = [], completion: @escaping (Result<Any, Error>) -> Void) {
        execute { res in
            switch res {
            case .success(let payload):
                do {
                    let obj = try JSONSerialization.jsonObject(with: payload.data, options: options)
                    completion(.success(obj))
                } catch {
                    completion(.failure(NetworkError.serializationFailed(error)))
                }
            case .failure(let err): completion(.failure(err))
            }
        }
    }
    
    public func responseDecodable<T: Decodable>(of type: T.Type, decoder: JSONDecoder = JSONDecoder(), completion: @escaping (Result<T, Error>) -> Void) {
        execute { res in
            switch res {
            case .success(let payload):
                do {
                    let value = try decoder.decode(T.self, from: payload.data)
                    completion(.success(value))
                } catch {
                    completion(.failure(NetworkError.serializationFailed(error)))
                }
            case .failure(let err): completion(.failure(err))
            }
        }
    }
    
    // MARK: - Async/Await Serializers
    
    public func serializingData() async throws -> (data: Data, response: HTTPURLResponse) {
        return try await withCheckedThrowingContinuation { cont in
            self.responseData { cont.resume(with: $0.map { ($0, HTTPURLResponse()) }) }
        }
    }
    
    public var _response: HTTPURLResponse?
    
    public var resumeData: Data? { nil }
    
    public struct Payload { public let data: Data; public let response: HTTPURLResponse }
    
    public func serializingString(encoding: String.Encoding = .utf8) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            self.responseString(encoding: encoding) { cont.resume(with: $0) }
        }
    }
    
    public func serializingJSON(options: JSONSerialization.ReadingOptions = []) async throws -> Any {
        try await withCheckedThrowingContinuation { cont in
            self.responseJSON(options: options) { cont.resume(with: $0) }
        }
    }
    
    public func serializingDecodable<T: Decodable>(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) -> DecodableSerializer<T> {
        DecodableSerializer<T>(request: self, decoder: decoder)
    }
    
    public struct DecodableSerializer<T: Decodable> {
        let request: DataRequest
        let decoder: JSONDecoder
        public var value: T {
            get async throws {
                try await withCheckedThrowingContinuation { cont in
                    request.responseDecodable(of: T.self, decoder: decoder) { cont.resume(with: $0) }
                }
            }
        }
    }
    
    // MARK: - Execution
    
    private func execute(completion: @escaping (Result<Payload, Error>) -> Void) {
        if let storedError { completion(.failure(storedError)); return }
        guard let request else { completion(.failure(NetworkError.invalidURL)); return }
        
        func perform() {
            task = session.dataTask(with: request) { data, response, error in
                if let error {
                    Task {
                        if let retrier = self.retrier, await retrier.retry(request, dueTo: error, attempt: self.attempt) {
                            self.attempt += 1
                            perform()
                            return
                        }
                        completion(.failure(NetworkError.underlying(error)))
                    }
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    completion(.failure(NetworkError.underlying(URLError(.badServerResponse)))); return
                }
                let payload = Payload(data: data ?? Data(), response: http)
                // Validate
                if !self.validation.acceptableStatusCodes.contains(http.statusCode) {
                    completion(.failure(NetworkError.serverError(statusCode: http.statusCode, data: data)))
                    return
                }
                if let types = self.validation.acceptableContentTypes,
                   let mime = http.value(forHTTPHeaderField: "Content-Type"),
                   !types.contains(where: { mime.contains($0) }) {
                    completion(.failure(NetworkError.serverError(statusCode: http.statusCode, data: data)))
                    return
                }
                completion(.success(payload))
            }
            task?.resume()
        }
        
        perform()
    }
}
