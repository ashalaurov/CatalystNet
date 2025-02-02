//
//  HttpClient.swift
//
//  Created by Ivan Manov on 01.07.2020.
//  Copyright © 2020 @hellc. All rights reserved.
//

import Foundation

public typealias JSON = [String: Any]
public typealias HTTPHeaders = [String: String]

public struct AnyResponse: Decodable {}

public enum RequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

open class HttpClient {
    private(set) var baseUrl: String
    
    public init(baseUrl: String) {
        self.baseUrl = baseUrl
    }

    public var commonParams: JSON = [:]
    
    // swiftlint:disable function_body_length
    open func load<T, E>(
        resource: Resource<T, E>,
        completion: @escaping (Result<T, E>) -> Void,
        logging: Bool = false,
        logsHandler: @escaping (_ input: RequestLog, _ output: ResponseLog?) -> Void = { _, _ in }
    ) -> URLSessionTask? {
        #if !os(watchOS)
        if !Reachability.isConnectedToNetwork() {
            completion(.failure(.noInternetConnection))
            return nil
        }
        #endif

        var newResouce = resource

        newResouce.params += self.commonParams

        var request = URLRequest(baseUrl: baseUrl, resource: newResouce)

        var requestLog: RequestLog?
        
        if logging {
            DispatchQueue.global(qos: .background).async {
                requestLog = RequestLog(
                    timestamp: Date(),
                    httpMethod: request.httpMethod,
                    headers: request.allHTTPHeaderFields,
                    body: String(data: request.httpBody ?? Data(), encoding: .utf8),
                    path: resource.path.absolutePath,
                    host: self.baseUrl,
                    url: request.url?.absoluteString
                )
            }
        }
        
        request.timeoutInterval = 15.0
        
        if resource.download {
            let task = URLSession.shared.downloadTask(with: request) { localURL, response, error in
                guard let response = response as? HTTPURLResponse else {
                    completion(.failure(.other("HTTPURLResponse is missed")))
                    return
                }
                
                let statusCode = response.statusCode
                
                if (200 ..< 300) ~= statusCode {
                    if let localURL = localURL as? T {
                        completion(.success(localURL))
                    } else {
                        completion(.failure(.unsupportedResource))
                    }
                } else if statusCode == 401 {
                    completion(.failure(.unauthorized))
                } else if statusCode == 403 {
                    completion(.failure(.forbidden))
                } else if (500 ..< 600) ~= statusCode {
                    completion(.failure(.serverError))
                } else {
                    completion(.failure(.other("Unknown")))
                }
            }
            
            task.resume()
            
            return task
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            // Parsing incoming data
            guard let response = response as? HTTPURLResponse else {
                completion(.failure(.other("HTTPURLResponse is missed")))
                return
            }
            
            let statusCode = response.statusCode
            let output = String(data: data ?? Data(), encoding: .utf8) ?? ""
            
            if logging, let requestLog = requestLog  {
                DispatchQueue.global(qos: .background).async {
                    let headers = response.allHeaderFields
                    let timestamp = Date()
                    let responseLog = ResponseLog(
                        timestamp: timestamp,
                        responseTime: timestamp.timeIntervalSince(requestLog.timestamp),
                        headers: headers,
                        body: output,
                        code: statusCode
                    )
                    
                    DispatchQueue.main.async {
                        logsHandler(requestLog, responseLog)
                    }
                }
            }
            
            if (200 ..< 300) ~= statusCode {
                if let value = data.flatMap(resource.parse) {
                    completion(.success(value))
                } else {
                    completion(.failure(.unsupportedResource))
                }
            } else if statusCode == 401 {
                completion(.failure(.unauthorized))
            } else if statusCode == 403 {
                completion(.failure(.forbidden))
            } else if (500 ..< 600) ~= statusCode {
                completion(.failure(.serverError))
            } else if let error = data.flatMap(resource.parseError) {
                completion(.failure(.custom(error)))
            } else {
                completion(.failure(.other(output)))
            }
        }

        task.resume()

        return task
    }
}

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
extension HttpClient {
    open func load<T, E>(resource: Resource<T, E>) async throws -> T {
        #if !os(watchOS)
        if !Reachability.isConnectedToNetwork() {
            throw CatalystError<E>.noInternetConnection
        }
        #endif

        var newResouce = resource

        newResouce.params += self.commonParams

        var request = URLRequest(baseUrl: baseUrl, resource: newResouce)
        
        request.timeoutInterval = 15.0
        
        if resource.download {
            do {
                let (localURL, response) = try await URLSession.shared.download(for: request)

                guard let response = response as? HTTPURLResponse else {
                    throw CatalystError<E>.other("HTTPURLResponse is missed")
                }
                
                let statusCode = response.statusCode
                guard let localURL = localURL as? T, (200 ..< 300) ~= statusCode else {
                    if statusCode == 401 {
                        throw CatalystError<E>.unauthorized
                    } else if statusCode == 403 {
                        throw CatalystError<E>.forbidden
                    } else {
                        throw CatalystError<E>.other("File download error")
                    }
                }
                
                return localURL
            } catch {
                throw CatalystError<E>.other(error.localizedDescription)
            }
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let response = response as? HTTPURLResponse else {
                throw CatalystError<E>.other("HTTPURLResponse is missed")
            }
            
            let statusCode = response.statusCode
            let output = String(data: data, encoding: .utf8) ?? ""
            
            

            
            if (200 ..< 300) ~= statusCode {
                guard let value = resource.parse(data) else {
                    throw CatalystError<E>.unsupportedResource
                }
                
                return value
            } else if statusCode == 401 {
                throw CatalystError<E>.unauthorized
            } else if statusCode == 403 {
                throw CatalystError<E>.forbidden
            } else if (500 ..< 600) ~= statusCode {
                throw CatalystError<E>.serverError
            } else if let error = resource.parseError(data) {
                throw CatalystError<E>.custom(error)
            } else {
                throw CatalystError<E>.other(output)
            }
        } catch {
            throw CatalystError<E>.other(error.localizedDescription)
        }
    }
}
