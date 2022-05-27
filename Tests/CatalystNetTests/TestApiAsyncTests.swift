//
//  TestApiAsyncTests.swift
//
//  Created by Ivan Manov on 26.05.2022.
//  Copyright © 2020 @hellc. All rights reserved.
//

import XCTest
@testable import CatalystNet

@available(iOS 13.0.0, *)
@available(macOS 10.15.0, *)
final class TestApiAsyncTests: XCTestCase {
    private let testApi = TestApi(baseUrl: "https://jsonplaceholder.typicode.com")
    
    func testPost() async {
        let id = "42"
        let (post, error) = await self.testApi.post(with: id)
        
        XCTAssertNil(error)
        XCTAssertNotNil(post)
        XCTAssertEqual(post?.id, 42)
    }
    
    func testPhotos() async {
        let albumId = 1
        let (photos, error) = await self.testApi.photos(with: albumId)
        
        XCTAssertNil(error)
        XCTAssertNotNil(photos)
        XCTAssertEqual(photos?.count, 50, "First album photos count")
    }
    
    func testPhoto() async {
        let photoId = 42
        let (photo, error) = await self.testApi.photo(photoId: photoId)
        
        XCTAssertNil(error)
        XCTAssertNotNil(photo)
        XCTAssertEqual(photo?.albumId, 1)
        XCTAssertEqual(photo?.id, 42)
        XCTAssertNotNil(photo?.url)
    }
}
