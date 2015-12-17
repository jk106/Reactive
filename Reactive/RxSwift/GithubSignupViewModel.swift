//
//  GithubSignupViewModel.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa

class GithubSignupViewModel {
    
    private let API: GitHubAPI
    private let validationService: GitHubValidationService
    
    // inputs {
    
    let username = Variable("")
    let password = Variable("")
    let repeatedPassword = Variable("")
    
    let loginTaps = PublishSubject<Void>()
    
    // }
    
    // outputs {
    
    //
    let validatedUsername: Observable<ValidationResult>
    let validatedPassword: Observable<ValidationResult>
    let validatedPasswordRepeated: Observable<ValidationResult>
    
    // Is signup button enabled
    let signupEnabled: Observable<Bool>
    
    // Has user signed in
    let signedIn: Observable<Bool>
    
    // }
    
    let dates = Variable([NSDate]())
    
    init(API: GitHubAPI, validationService: GitHubValidationService) {
        self.API = API
        self.validationService = validationService
        
        validatedUsername = username
            .flatMapLatest { username in
                return validationService.validateUsername(username)
                    .observeOn(MainScheduler.sharedInstance)
                    .catchErrorJustReturn(.Failed(message: "Error contacting server"))
            }
            .shareReplay(1)
        
        validatedPassword = password
            .map { password in
                return validationService.validatePassword(password)
            }
            .shareReplay(1)
        
        validatedPasswordRepeated = combineLatest(password, repeatedPassword, resultSelector: validationService.validateRepeatedPassword)
            .shareReplay(1)
        
        let usernameAndPassword = combineLatest(username, password) { ($0, $1) }
        
        signedIn = loginTaps.withLatestFrom(usernameAndPassword)
            .flatMapLatest { (username, password) in
                return API.signup(username, password: password)
                    .observeOn(MainScheduler.sharedInstance)
                    .catchErrorJustReturn(false)
            }
            .shareReplay(1)
        
        signupEnabled = combineLatest(
            validatedUsername,
            validatedPassword,
            validatedPasswordRepeated
            )   { username, password, repeatPassword in
                username.isValid &&
                    password.isValid &&
                    repeatPassword.isValid
            }
            .shareReplay(1)
    }
}