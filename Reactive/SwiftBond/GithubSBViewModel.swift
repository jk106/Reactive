//
//  GithubSBViewModel.swift
//  Reactive
//
//  Created by Juan Chaparro on 20/04/16.
//  Copyright © 2016 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import Bond
import Alamofire

class GithubSBViewModel {
    
    private let validationService: GitHubRACValidationService
    
    // inputs
    let username:Observable<String?> = Observable("")
    let password:Observable<String?> = Observable("")
    let repeatedPassword:Observable<String?> = Observable("")
    
    let loginTaps = Observable()
    
    let disposeBag = DisposeBag()
    
    //outputs
    let validUsername = Observable(ValidationResult.Empty)
    let validPassword = Observable(ValidationResult.Empty)
    let validRepeat = Observable(ValidationResult.Empty)
    
    let signupEnabled = Observable(false)
    let signingIn = Observable(false)
    let signedIn = Observable(false)
    
    var dates = ObservableArray([NSDate()])

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
        self.username.skip(2).observe{
            username in
            self.fetchUsername(username!)
            }
        self.validUsername.combineLatestWith(self.validPassword).combineLatestWith(self.validRepeat)
            .map{
                v1,v2 in
                return v1.0.isValid && v1.1.isValid && v2.isValid
            }.bindTo(self.signupEnabled)
        self.loginTaps.skip(1).combineLatestWith(self.username.skip(1)).combineLatestWith(self.password).observe{
            username, password in
            self.signingIn.value = true
            self.signupEnabled.value = false
            self.signIn(username.1!, password: password!)
        }
    }
    
    func signIn(username: String, password: String)
    {
        let signupResult = arc4random() % 5 == 0 ? false : true
        let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
        dispatch_async(dispatch_get_global_queue(priority, 0)) {
            NSThread.sleepForTimeInterval(2)
            
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                print("This is run on the main queue, after the previous code in outer block")
                self.signedIn.value = signupResult
                self.signingIn.value = false
                self.signupEnabled.value = true
                if(signupResult){
                    self.dates.append(NSDate())
                }
            })
        }
    }
    
    func fetchUsername(query: String) {
        self.validUsername.value = ValidationResult.Validating
        Manager.sharedInstance.request(Router.Query(query: query)).response {
            request, response, data, error in
            if let error = error {
                self.validUsername.value = ValidationResult.Failed(message: "Unable to connect \(error)")
            } else {
                self.validUsername.value = (response?.statusCode == 404) ? ValidationResult.OK(message: "Username available")
                    : ValidationResult.Failed(message: "Username already taken")
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
