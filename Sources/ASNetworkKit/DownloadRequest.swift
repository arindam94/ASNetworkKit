//
//  DownloadRequest.swift
//  ASNetworkKit
//
//  Copyright (c) 2025 Arindam Santra. All rights reserved.
//

import Foundation

public final class DownloadRequest {
    private let session: URLSession
    private let url: URL
    private let destination: URL
    private var task: URLSessionDownloadTask?
    private var storedError: Error?
    
    init(session: URLSession, url: URL, destination: URL, error: Error? = nil) {
        self.session = session; self.url = url; self.destination = destination; self.storedError = error
    }
    
    public func cancel() { task?.cancel() }
    
    public func response(completion: @escaping (Result<URL, Error>) -> Void) {
        if let storedError { completion(.failure(storedError)); return }
        task = session.downloadTask(with: url) { temp, response, error in
            if let error {
                completion(.failure(NetworkError.underlying(error))); return
            }
            guard let temp else {
                completion(.failure(NetworkError.underlying(URLError(.unknown)))); return
            }
            do {
                try? FileManager.default.removeItem(at: self.destination)
                try FileManager.default.moveItem(at: temp, to: self.destination)
                completion(.success(self.destination))
            } catch {
                completion(.failure(error))
            }
        }
        task?.resume()
    }
    
    public func serializingDownloadedFile() -> DownloadedFileSerializer {
        DownloadedFileSerializer(request: self)
    }
    
    public struct DownloadedFileSerializer {
        let request: DownloadRequest
        public var value: URL {
            get async throws {
                try await withCheckedThrowingContinuation { cont in
                    request.response { cont.resume(with: $0) }
                }
            }
        }
    }
}
