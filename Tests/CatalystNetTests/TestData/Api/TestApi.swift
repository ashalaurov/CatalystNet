//
//  TestApi.swift
//
//  Created by Ivan Manov on 01.07.2020.
//  Copyright © 2020 @hellc. All rights reserved.
//

import Foundation
@testable import CatalystNet

class TestApi: Api {
    static let shared = TestApi()
    
    override func load<T, E>(_ resource: Resource<T, E>,
                          _ client: RestClient = TestApiClient.shared,
                          multitasking: Bool = false,
                          completion: @escaping (Result<Any, E>) -> Void) {
        super.load(resource, client, multitasking: multitasking, completion: completion)
    }
    
    func post(with id: String, completion: @escaping (Post?, RestError<String>?) -> Void) {
        var resource = Resource<Post, String>(path: Api.resource(TestApi.posts, with: id))
        
        resource.method = .get
        
        self.load(resource) { response in
            if let post = response.value as? Post {
                completion(post, nil)
            } else if let error = response.error {
                completion(nil, error)
            }
        }
    }
}
