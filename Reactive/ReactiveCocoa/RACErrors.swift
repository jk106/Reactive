//
//  RACErrors.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import Foundation

enum GithubError: Int {
    case InvalidUser = 0,
    InvalidPassword,
    APIError,
    PasswordMismatch,
    NoError
    
    func toError() -> NSError {
        return NSError(domain:"Github", code: self.rawValue, userInfo: nil)
    }
}