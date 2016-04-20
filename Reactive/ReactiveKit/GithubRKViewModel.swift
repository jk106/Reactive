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
    let username:Property<String?> = Property("")
    let password:Property<String?> = Property("")
    let repeatedPassword:Property<String?> = Property("")
    
    let loginTaps = Property()
    
    let disposeBag = DisposeBag()
    
    //outputs
    let validUsername = Property(ValidationResult.Empty)
    let validPassword = Property(ValidationResult.Empty)
    let validRepeat = Property(ValidationResult.Empty)
    
    let signupEnabled = Property(false)
    let signingIn = Property(false)
    let signedIn = Property(false)
    
    var dates = CollectionProperty([NSDate()])
    
    init(validationService: GitHubRACValidationService) {
        self.dates.removeLast()
        self.validationService = validationService
        self.password.map{
            password in
            return self.validationService.validatePassword(password!)
            }.bindTo(self.validPassword)
        
        self.repeatedPassword.skip(2).combineLatestWith(self.password).map{
            p1,p2 in
            return self.validationService.validateRepeatedPassword(p1!, repeatedPassword: p2!)
            }.bindTo(self.validRepeat)
        self.username.skip(2).flatMap(.Latest){
            username in
            self.fetchUsername(username!).startWith(ValidationResult.Validating).toStream(recoverWith: ValidationResult.Validating)
        }.bindTo(self.validUsername)
        self.validUsername.combineLatestWith(self.validPassword).combineLatestWith(self.validRepeat)
            .map{
                v1,v2 in
                return v1.0.isValid && v1.1.isValid && v2.isValid
            }.bindTo(self.signupEnabled)
        self.loginTaps.skip(1).combineLatestWith(self.username.skip(1)).zipWith(self.password).observeNext{
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
                    if(result){
                        self.dates.append(NSDate())
                    }
                default:
                    self.signingIn.value = false
                    self.signupEnabled.value = true
                }
            }.disposeIn(self.disposeBag)
        }.disposeIn(disposeBag)
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
                    observer.completed()
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
                    observer.completed()
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
