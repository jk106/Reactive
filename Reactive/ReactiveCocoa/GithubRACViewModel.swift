//
//  GithubRACViewModel.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import ReactiveCocoa
import Result

class GithubRACViewModel {
    
    private let validationService: GitHubValidationService
    
    // inputs {
    
    let username = MutableProperty<String>("")
    let password = MutableProperty<String>("")
    let repeatedPassword = MutableProperty<String>("")
    
    lazy var loginTaps:Action<Void, Bool, NSError> = { [unowned self] in
        return Action(enabledIf: self.signedUpEnabled, { _ in
            let signupResult = arc4random() % 5 == 0 ? false : true
            print("\(self.password.value), \(self.username.value)")
            let sp = SignalProducer<Bool, NSError>
                {
                    sink, disposable in
                    let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
                    dispatch_async(dispatch_get_global_queue(priority, 0)) {
                        NSThread.sleepForTimeInterval(2)
                        
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            print("This is run on the main queue, after the previous code in outer block")
                            if(signupResult){
                                sink.sendNext(signupResult)
                                sink.sendCompleted()
                            }
                            else{
                                sink.sendFailed(GithubError.APIError.toError())
                            }
                        })
                    }
                }
                .on(started:{
                    _ in
                    self.signedUpEnabled.value = false;
                    },
                    completed:
                    {
                        _ in
                        self.signedUpEnabled.value = true;
                        self.dates.value.append(NSDate())
                    },
                    next:
                    {
                        response in self.signedIn.value = response
                    },
                    failed:
                    {
                        error in self.signedIn.value = false
                        self.signedUpEnabled.value = true;
                })
            return sp
        })
        }()
    
    //outputs
    let validUsername = MutableProperty<ValidationResult>(ValidationResult.Empty)
    let validPassword = MutableProperty<ValidationResult>(ValidationResult.Empty)
    let validRepeat = MutableProperty<ValidationResult>(ValidationResult.Empty)
    let signedUpEnabled = MutableProperty<Bool>(false)
    let signedIn = MutableProperty<Bool>(false)
    
    let dates = MutableProperty<[NSDate]>([NSDate]())
    
    init(validationService: GitHubValidationService) {
        self.validationService = validationService
        self.password.producer.map
            {
                password in
                return self.validationService.validatePassword(password)
            }
            .observeOn(QueueScheduler.mainQueueScheduler).start(Observer(failed: {
                print("Error \($0)")
                },
                next: {
                    response in
                    self.validPassword.value = response
            }))
        self.repeatedPassword.producer.skip(2).combineLatestWith(self.password.producer)
            .map{p1,p2 in
                return self.validationService.validateRepeatedPassword(p1, repeatedPassword: p2)
            }
            .observeOn(QueueScheduler.mainQueueScheduler).start(Observer(failed: {
                print("Error \($0)")
                },
                next: {
                    response in
                    self.validRepeat.value = response
            }))
        
        self.username.producer.skip(2).on(event: {
            _ in self.validUsername.value = ValidationResult.Validating
        })
            .flatMap(FlattenStrategy.Latest) {
                (query: String) -> SignalProducer<(NSData, NSURLResponse), NoError> in
                let URLRequest = self.searchRequest(query)
                return NSURLSession.sharedSession().rac_dataWithRequest(URLRequest)
                    .flatMapError { error in
                        print("Network error occurred: \(error)")
                        return SignalProducer.empty
                }
            }
            .map { (data, URLResponse) -> Bool in
                let http = URLResponse as! NSHTTPURLResponse
                return http.statusCode == 404
            }
            .observeOn(UIScheduler())
            .start(Observer(failed: {
                print("Error \($0)")
                },
                next: {
                    response in
                    self.validUsername.value = response ? ValidationResult.OK(message: "Username available")
                        : ValidationResult.Failed(message: "Username already taken")
            }))
        
        self.validUsername.producer.combineLatestWith(self.validPassword.producer)
            .combineLatestWith(self.validRepeat.producer).map
            {
                v1,v3 in
                return v1.0.isValid && v1.1.isValid && v3.isValid
            }
            .observeOn(QueueScheduler.mainQueueScheduler).start(Observer(failed: {
                print("Error \($0)")
                },
                next: {
                    response in
                    self.signedUpEnabled.value = response
            }))
    }
    
    func searchRequest(username:String) -> NSURLRequest
    {
        let URL = NSURL(string: "https://github.com/\(URLEscape(username))")!
        return NSURLRequest(URL: URL)
    }
    func URLEscape(pathSegment: String) -> String {
        return pathSegment.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
    }
    
}
