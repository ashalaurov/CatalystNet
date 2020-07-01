//
//  Post.swift
//
//  Created by Ivan Manov on 01.07.2020.
//  Copyright © 2020 @hellc. All rights reserved.
//

import Foundation

struct Post: Decodable {
    var id: UInt
    var userId: UInt
    var title: String
    var body: String
}
