//
//  GithubRKViewModel.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/11/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import ReactiveKit
import Alamofire

class GithubRKViewModel {
    
    private let validationService: GitHubRACValidationService
    
    // inputs
    let username:Observable<String?> = Observable("")
    let password:Observable<String?> = Observable("")
    let repeatedPassword:Observable<String?> = Observable("")
    
    let loginTaps = Observable()
    
    //outputs
    let validUsername = Observable(ValidationResult.Empty)
    let validPassword = Observable(ValidationResult.Empty)
    let validRepeat = Observable(ValidationResult.Empty)
    
    let signupEnabled = Observable(false)
    let signingIn = Observable(false)
    let signedIn = Observable(false)
    
    init(validationService: GitHubRACValidationService) {
        self.validationService = validationService
        self.password.map{
            password in
            return self.validationService.validatePassword(password!)
            }.observe
            {
                result in
                self.validPassword.value = result
        }
        self.repeatedPassword.skip(2).combineLatestWith(self.password).map{
            p1,p2 in
            return self.validationService.validateRepeatedPassword(p1!, repeatedPassword: p2!)
            }.observe
            {
                result in
                self.validRepeat.value = result
        }
        self.username.skip(2).observe{
            username in
            self.validUsername.value = ValidationResult.Validating
            self.fetchUsername(username!).bindNextTo(self.validUsername)
        }
        self.validUsername.combineLatestWith(self.validPassword).combineLatestWith(self.validRepeat)
            .map{
                v1,v2 in
                return v1.0.isValid && v1.1.isValid && v2.isValid
            }.observe
            {
                result in
                self.signupEnabled.value = result
        }
        self.loginTaps.skip(1).zipWith(self.username.skip(1)).zipWith(self.password).observe{
            username, password in
            self.signingIn.value = true
            self.signupEnabled.value = false
            self.signIn(username.1!, password: password!).observe{
                event in
                switch (event)
                {
                case .Next(let result):
                    self.signedIn.value = result
                    self.signingIn.value = false
                    self.signupEnabled.value = true
                default:
                    self.signingIn.value = false
                    self.signupEnabled.value = true
                }
            }
        }
    }
    
    func signIn(username: String, password: String) -> Operation<Bool, NSError>
    {
        return Operation { observer in
            let signupResult = arc4random() % 5 == 0 ? false : true
            let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
            dispatch_async(dispatch_get_global_queue(priority, 0)) {
                NSThread.sleepForTimeInterval(2)
                
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    print("This is run on the main queue, after the previous code in outer block")
                    observer.next(signupResult)
                    observer.success()
                })
            }
            return BlockDisposable {
                
            }
        }
    }
    
    func fetchUsername(query: String) -> Operation<ValidationResult, NSError> {
        return Operation { observer in
            let request = Manager.sharedInstance.request(Router.Query(query: query)).response {
                request, response, data, error in
                if let error = error {
                    observer.failure(error)
                } else {
                    observer.next((response?.statusCode == 404) ? ValidationResult.OK(message: "Username available")
                        : ValidationResult.Failed(message: "Username already taken"))
                    observer.success()
                }
            }
            return BlockDisposable {
                request.cancel()
            }
        }
    }
    
    enum Router: URLRequestConvertible {
        static let baseURLString = "https://github.com/"
        
        case Query (query: String)
        
        var URLRequest: NSMutableURLRequest {
            let result: (path: String, parameters: [String: AnyObject]) = {
                switch self {
                case .Query(query: let aQuery):
                    return (aQuery, [String : AnyObject]())
                }
            }()
            
            let URL = NSURL(string: Router.baseURLString)
            let URLRequest = NSMutableURLRequest(URL: URL!.URLByAppendingPathComponent(result.path))
            let encoding = Alamofire.ParameterEncoding.URL
            
            return encoding.encode(URLRequest, parameters: result.parameters).0
        }
    }
    
}
