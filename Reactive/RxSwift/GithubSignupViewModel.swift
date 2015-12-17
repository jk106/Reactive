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
import Action

class GithubSignupViewModel {
    
    private let API: GitHubAPI
    private let validationService: GitHubValidationService
    
    // inputs {
    
    let username = Variable("")
    let password = Variable("")
    let repeatedPassword = Variable("")
    
    var action: CocoaAction = CocoaAction{_ in
        return create{_ in
            return NopDisposable.instance
        }
    }
    // }
    
    // outputs {
    
    //
    let validatedUsername: Observable<ValidationResult>
    let validatedPassword: Observable<ValidationResult>
    let validatedPasswordRepeated: Observable<ValidationResult>
    
    // Is signup button enabled
    let signupEnabled: Observable<Bool>
    
    // Has user signed in
    var signedIn: Action<Void, Bool> = Action{
        _ in
        return just(false)
    }
    
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
        
        signedIn = Action{
            _ in
            return combineLatest(self.username, self.password) { ($0, $1) }
                .flatMapLatest{
                    (username, password) in
                    API.signup(username, password: password)
                        .observeOn(MainScheduler.sharedInstance)
            }.take(1)
        }
        action = CocoaAction (enabledIf: signupEnabled){
            return create {
                [weak self] observer -> RxSwift.Disposable in
                self?.signedIn.execute()
                return (self?.signedIn.elements.take(1).map{result in
                    print("cc\(result)")
                    }.subscribe(observer))!
            }
        }
    }
}