//
//  RACImplementations.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import Foundation

class GitHubRACDefaultValidationService: GitHubRACValidationService {
    
    let minPasswordCount = 5
    
    func validatePassword(password: String) -> ValidationResult {
        let numberOfCharacters = password.characters.count
        if numberOfCharacters == 0 {
            return .Empty
        }
        
        if numberOfCharacters < minPasswordCount {
            return .Failed(message: "Password must be at least \(minPasswordCount) characters")
        }
        
        return .OK(message: "Password acceptable")
    }
    
    func validateRepeatedPassword(password: String, repeatedPassword: String) -> ValidationResult {
        if repeatedPassword.characters.count == 0 {
            return .Empty
        }
        
        if repeatedPassword == password {
            return .OK(message: "Password repeated")
        }
        else {
            return .Failed(message: "Password different")
        }
    }
}