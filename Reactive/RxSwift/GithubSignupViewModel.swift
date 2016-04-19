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
    
    // }
    
    // outputs {
    
    //
    let validatedUsername: Observable<ValidationResult>
    let validatedPassword: Observable<ValidationResult>
    let validatedPasswordRepeated: Observable<ValidationResult>
    
    // Is signup button enabled
    let signupEnabled: Observable<Bool>
    
    // Has user signed in
    var signedIn: CocoaAction = CocoaAction{_ in
        return Observable.create{_ in
            return NopDisposable.instance
        }
    }
    
    private var _errors = PublishSubject<String>()
    var errors: Observable<String> {
        return _errors.asObservable()
    }
    
    private var _success = PublishSubject<String>()
    var success: Observable<String> {
        return _success.asObservable()
    }
    
    // }
    
    let dates = Variable([NSDate]())
    
    init(API: GitHubAPI, validationService: GitHubValidationService) {
        self.API = API
        self.validationService = validationService
        
        validatedUsername = username.asObservable()
            .flatMapLatest { username in
                return validationService.validateUsername(username)
                    .observeOn(MainScheduler.instance)
                    .catchErrorJustReturn(.Failed(message: "Error contacting server"))
            }
            .shareReplay(1)
        
        validatedPassword = password.asObservable()
            .map { password in
                return validationService.validatePassword(password)
            }
            .shareReplay(1)
        
        validatedPasswordRepeated = Observable.combineLatest(password.asObservable(), repeatedPassword.asObservable()
            , resultSelector: validationService.validateRepeatedPassword)
            .shareReplay(1)
        
        signupEnabled = Observable.combineLatest(
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
            return Observable.combineLatest(self.username.asObservable(), self.password.asObservable()) { ($0, $1) }
                .flatMapLatest{
                    (username, password) in
                    API.signup(username, password: password)
                        .observeOn(MainScheduler.instance)
                        .doOn { event in
                            switch event {
                            case .Next(let signedUp) where signedUp == false:
                                self._errors.onNext("Mock: Sign in to GitHub failed")
                            case .Next(let signedUp) where signedUp == true:
                                self._success.onNext("Mock: Signed in to GitHub.")
                                self.dates.value.append(NSDate())
                            default: break
                            }
                        }
                        .map { _ in Void() }
                }.take(1)
        }
    }
}