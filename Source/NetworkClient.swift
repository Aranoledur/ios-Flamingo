//
//  NetworkClient.swift
//  Flamingo
//
//  Created by Георгий Касапиди on 16.05.16.
//  Copyright © 2016 ELN. All rights reserved.
//

import Foundation
import Alamofire

public protocol NetworkClient: class {
    
    func sendRequest<T: NetworkRequest>(networkRequest: T, completionHandler: ((T.T?, NSError?) -> Void)?) -> CancelableOperation
    func shouldUseCachedResponseDataIfError(error: NSError?) -> Bool
}

public class NetworkDefaultClient: NetworkClient {
    
    private static let operationQueue = dispatch_queue_create("com.flamingo.operation-queue", DISPATCH_QUEUE_CONCURRENT)
    
    private let configuration: NetworkConfiguration
    private let offlineCacheManager: NetworkOfflineCacheManager?
    
    public let networkManager: Manager
    
    public init(configuration: NetworkConfiguration,
                offlineCacheManager: NetworkOfflineCacheManager? = nil,
                networkManager: Manager = Manager.sharedInstance) {
        self.configuration = configuration
        self.offlineCacheManager = offlineCacheManager
        self.networkManager = networkManager
    }
    
    public func sendRequest<T : NetworkRequest>(networkRequest: T, completionHandler: ((T.T?, NSError?) -> Void)?) -> CancelableOperation {
        let URLRequest = networkRequest.URLRequestWithBaseURL(configuration.baseURL, timeoutInterval: configuration.defaultTimeoutInterval)
        
        let _completionQueue = networkRequest.completionQueue ?? self.configuration.completionQueue
        
        if configuration.useMocks {
            if let mock = networkRequest.mockObject {
                let mockOperation = NetworkMockOperation(URLRequest: URLRequest,
                                                         mock: mock,
                                                         dispatchQueue: NetworkDefaultClient.operationQueue,
                                                         completionQueue: _completionQueue,
                                                         responseSerializer: networkRequest.responseSerializer,
                                                         completionHandler: completionHandler)
                
                mockOperation.resume()
                
                return mockOperation
            }
        }
        
        let _useCache = networkRequest.useCache && self.offlineCacheManager != nil
        
        let _request = networkManager.request(URLRequest).validate().response(queue: _completionQueue) { (request, response, data, error) in
            var _data: NSData? = data
            
            if _useCache && self.shouldUseCachedResponseDataIfError(error) {
                dispatch_sync(NetworkDefaultClient.operationQueue, {
                    _data = self.offlineCacheManager!.responseDataForRequest(URLRequest)
                })
            }
            
            dispatch_async(NetworkDefaultClient.operationQueue, {
                let result = networkRequest.responseSerializer.serializeResponse(request, response, _data, nil)
                
                switch result {
                case .Success(let value):
                    if _useCache {
                        self.offlineCacheManager!.setResponseData(_data!, forRequest: URLRequest)
                    }
                    
                    if let completionHandler = completionHandler {
                        dispatch_async(_completionQueue, {
                            completionHandler(value, error)
                        })
                    }
                case .Failure(let error):
                    if let completionHandler = completionHandler {
                        dispatch_async(_completionQueue, {
                            completionHandler(nil, error)
                        })
                    }
                }
            })
        }
        
        if configuration.debugMode {
            debugPrint(_request)
        }
        
        if !networkManager.startRequestsImmediately {
            _request.resume()
        }
        
        return _request
    }
    
    public func shouldUseCachedResponseDataIfError(error: NSError?) -> Bool {
        guard let error = error else {
            return false
        }
        return error.isNetworkConnectionError
    }
}
