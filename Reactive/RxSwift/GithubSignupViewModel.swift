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

    // Is signing process in progress
    let signingIn: Observable<Bool>

    // }

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

        let signingIn = ActivityIndicator()
        self.signingIn = signingIn.asObservable()

        let usernameAndPassword = combineLatest(username, password) { ($0, $1) }

        signedIn = loginTaps.withLatestFrom(usernameAndPassword)
            .flatMapLatest { (username, password) in
                return API.signup(username, password: password)
                    .observeOn(MainScheduler.sharedInstance)
                    .catchErrorJustReturn(false)
                    .trackActivity(signingIn)
            }
            .flatMapLatest { loggedIn -> Observable<Bool> in
                let message = loggedIn ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
                return Wireframe().promptFor(message, cancelAction: "OK", actions: [])
                    // propagate original value
                    .map { _ in
                        loggedIn
                    }
            }
            .shareReplay(1)
        
        signupEnabled = combineLatest(
            validatedUsername,
            validatedPassword,
            validatedPasswordRepeated,
            signingIn.asObservable()
        )   { username, password, repeatPassword, signingIn in
                username.isValid &&
                password.isValid &&
                repeatPassword.isValid &&
                !signingIn
            }
            .shareReplay(1)
    }
}

class Wireframe {
    func promptFor<Action : CustomStringConvertible>(message: String, cancelAction: Action, actions: [Action]) -> Observable<Action> {
        #if os(iOS)
            return create { observer in
                let alertView = UIAlertView(
                    title: "RxExample",
                    message: message,
                    delegate: nil,
                    cancelButtonTitle: cancelAction.description
                )
                
                for action in actions {
                    alertView.addButtonWithTitle(action.description)
                }
                
                alertView.show()
                
                observer.on(.Next(alertView))
                
                return AnonymousDisposable {
                    alertView.dismissWithClickedButtonIndex(-1, animated: true)
                }
                }.flatMap { (alertView: UIAlertView) -> Observable<Action> in
                    return alertView.rx_didDismissWithButtonIndex.flatMap { index -> Observable<Action> in
                        if index < 0 {
                            return empty()
                        }
                        
                        if index == 0 {
                            return just(cancelAction)
                        }
                        
                        return just(actions[index - 1])
                    }
            }
        #elseif os(OSX)
            return failWith(NSError(domain: "Unimplemented", code: -1, userInfo: nil))
        #endif
    }
}

struct ActivityToken<E> : ObservableConvertibleType, Disposable {
    private let _source: Observable<E>
    private let _dispose: AnonymousDisposable
    
    init(source: Observable<E>, disposeAction: () -> ()) {
        _source = source
        _dispose = AnonymousDisposable(disposeAction)
    }
    
    func dispose() {
        _dispose.dispose()
    }
    
    func asObservable() -> Observable<E> {
        return _source
    }
}

/**
 Enables monitoring of sequence computation.
 
 If there is at least one sequence computation in progress, `true` will be sent.
 When all activities complete `false` will be sent.
 */
class ActivityIndicator : DriverConvertibleType {
    typealias E = Bool
    
    private let _lock = NSRecursiveLock()
    private let _variable = Variable(0)
    private let _loading: Driver<Bool>
    
    init() {
        _loading = _variable
            .map { $0 > 0 }
            .asDriver { (error: ErrorType) -> Driver<Bool> in
                _ = fatalError("Loader can't fail")
                return Drive.empty()
        }
    }
    
    func trackActivity<O: ObservableConvertibleType>(source: O) -> Observable<O.E> {
        return using({ () -> ActivityToken<O.E> in
            self.increment()
            return ActivityToken(source: source.asObservable(), disposeAction: self.decrement)
            }) { t in
                return t.asObservable()
        }
    }
    
    private func increment() {
        _lock.lock()
        _variable.value = _variable.value + 1
        _lock.unlock()
    }
    
    private func decrement() {
        _lock.lock()
        _variable.value = _variable.value - 1
        _lock.unlock()
    }
    
    func asDriver() -> Driver<E> {
        return _loading
    }
}

extension ObservableConvertibleType {
    func trackActivity(activityIndicator: ActivityIndicator) -> Observable<E> {
        return activityIndicator.trackActivity(self)
    }
}