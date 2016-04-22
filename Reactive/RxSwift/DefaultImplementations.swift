//
//  DefaultImplementations.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import RxSwift
import Alamofire

class GitHubRxDefaultValidationService: GitHubRxValidationService {
    let API: GitHubAPI

    static let sharedValidationService = GitHubRxDefaultValidationService(API: GitHubDefaultAPI.sharedAPI)

    init (API: GitHubAPI) {
        self.API = API
    }
    
    // validation
    
    let minPasswordCount = 5
    
    func validateUsername(username: String) -> Observable<ValidationResult> {
        if username.characters.count == 0 {
            return Observable.just(.Empty)
        }
        
        // this obviously won't be
        if username.rangeOfCharacterFromSet(NSCharacterSet.alphanumericCharacterSet().invertedSet) != nil {
            return Observable.just(.Failed(message: "Username can only contain numbers or digits"))
        }
        
        let loadingValue = ValidationResult.Validating
        
        return API
            .usernameAvailable(username)
            .map { available in
                if available {
                    return .OK(message: "Username available")
                }
                else {
                    return .Failed(message: "Username already taken")
                }
            }
            .startWith(loadingValue)
    }
    
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


class GitHubDefaultAPI : GitHubAPI {
    let URLSession: NSURLSession

    static let sharedAPI = GitHubDefaultAPI(
        URLSession: NSURLSession.sharedSession()
    )

    init(URLSession: NSURLSession) {
        self.URLSession = URLSession
    }
    
    func usernameAvailable(username: String) -> Observable<Bool> {
        // this is ofc just mock, but good enough
        
        let URL = NSURL(string: "https://github.com/\(URLEscape(username))")!
        let request = NSURLRequest(URL: URL)
        return self.URLSession.rx_response(request)
            .map { (maybeData, response) in
                return response.statusCode == 404
            }
            .catchErrorJustReturn(false)
    }
    
    func URLEscape(pathSegment: String) -> String {
        return pathSegment.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())!
    }
    
    func signup(username: String, password: String) -> Observable<Bool> {
        // this is also just a mock
        let signupResult = arc4random() % 5 == 0 ? false : true
        return Observable.just(signupResult)
            .concat(Observable.never())
            .throttle(2, scheduler: MainScheduler.instance)
            .take(1)
    }
}

class GitHubDefaultValidationService: GitHubValidationService {
    
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