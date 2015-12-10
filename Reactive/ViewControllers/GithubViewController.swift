//
//  GithubViewController.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa
import ReactiveCocoa

class GithubViewController: UIViewController {
    
    var library:Int!
    let rxViewModel = GithubSignupViewModel(
        API: GitHubDefaultAPI.sharedAPI,
        validationService: GitHubDefaultValidationService.sharedValidationService
    )
    
    let racViewModel = GithubRACViewModel(validationService: GitHubRACDefaultValidationService())
    
    var disposeBag = DisposeBag()
    
    var signupAction:CocoaAction!
    
    @IBOutlet weak var usernameOutlet: UITextField!
    @IBOutlet weak var usernameValidationOutlet: UILabel!
    
    @IBOutlet weak var passwordOutlet: UITextField!
    @IBOutlet weak var passwordValidationOutlet: UILabel!
    
    @IBOutlet weak var repeatedPasswordOutlet: UITextField!
    @IBOutlet weak var repeatedPasswordValidationOutlet: UILabel!
    
    @IBOutlet weak var signupOutlet: UIButton!
    @IBOutlet weak var signingUpOulet: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch(library){
        case 1:
            loadRAC()
        case 2:
            loadRx()
        case 3:
            print(self.title)
        default:
            print(self.title)
        }
        let tapBackground = UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard:"))
        view.addGestureRecognizer(tapBackground)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadRAC()
    {
        racViewModel.password <~ passwordOutlet.rac_text
        racViewModel.validPassword.producer.start(passwordValidationOutlet.rac_validationResult)
        
        racViewModel.repeatedPassword <~ repeatedPasswordOutlet.rac_text
        racViewModel.validRepeat.producer.start(repeatedPasswordValidationOutlet.rac_validationResult)
        
        racViewModel.username <~ usernameOutlet.rac_text
        racViewModel.validUsername.producer.start(usernameValidationOutlet.rac_validationResult)
        
        racViewModel.signedUpEnabled.producer.start(Observer { [weak self] event in
            switch event {
            case let .Next(result):
                self?.signupOutlet.enabled = result
                self?.signupOutlet.alpha = result ? 1.0 : 0.5
            case let .Failed(error):
                print(error)
            default:
                break
            }})
        
        racViewModel.signingIn.producer.start(Observer { [weak self] event in
            switch event {
            case let .Next(result):
                if (result)
                {
                    self?.signingUpOulet.startAnimating()
                }
                else
                {
                    self?.signingUpOulet.stopAnimating()
                }
            case let .Failed(error):
                print(error)
            default:
                break
            }})
        self.signupAction = CocoaAction(racViewModel.loginTaps, { _ in return () })
        signupOutlet.addTarget(signupAction, action: CocoaAction.selector, forControlEvents: UIControlEvents.TouchUpInside)
        racViewModel.signedIn.producer.start(Observer { event in
            switch event {
            case let .Next(result):
                print("User signed in \(result)")
            default:
                break
            }
            
            })
        racViewModel.loginTaps.values.observeOn(UIScheduler()).observeNext
            {_ in 
                let alertView = UIAlertView(
                    title: "RxExample",
                    message: "Mock: Signed in to GitHub.",
                    delegate: nil,
                    cancelButtonTitle: "OK"
                )
                
                alertView.show()
        }
        
        racViewModel.loginTaps.errors.observeOn(UIScheduler()).observeNext
            {_ in
                let alertView = UIAlertView(
                    title: "RxExample",
                    message: "Mock: Sign in to GitHub failed",
                    delegate: nil,
                    cancelButtonTitle: "OK"
                )
                
                alertView.show()
        }
    }
    
    func loadRx()
    {
        // bind UI values to view model {
        usernameOutlet.rx_text
            .bindTo(rxViewModel.username)
            .addDisposableTo(disposeBag)
        
        passwordOutlet.rx_text
            .bindTo(rxViewModel.password)
            .addDisposableTo(disposeBag)
        
        repeatedPasswordOutlet.rx_text
            .bindTo(rxViewModel.repeatedPassword)
            .addDisposableTo(disposeBag)
        
        signupOutlet.rx_tap
            .bindTo(rxViewModel.loginTaps)
            .addDisposableTo(disposeBag)
        // }
        
        
        // bind results to  {
        rxViewModel.signupEnabled
            .subscribeNext { [weak self] valid  in
                self?.signupOutlet.enabled = valid
                self?.signupOutlet.alpha = valid ? 1.0 : 0.5
            }
            .addDisposableTo(disposeBag)
        
        rxViewModel.validatedUsername
            .bindTo(usernameValidationOutlet.ex_validationResult)
            .addDisposableTo(disposeBag)
        
        rxViewModel.validatedPassword
            .bindTo(passwordValidationOutlet.ex_validationResult)
            .addDisposableTo(disposeBag)
        
        rxViewModel.validatedPasswordRepeated
            .bindTo(repeatedPasswordValidationOutlet.ex_validationResult)
            .addDisposableTo(disposeBag)
        
        rxViewModel.signingIn
            .bindTo(signingUpOulet.rx_animating)
            .addDisposableTo(disposeBag)
        
        rxViewModel.signedIn
            .subscribeNext { signedIn in
                print("User signed in \(signedIn)")
                let message = signedIn ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
                let alertView = UIAlertView(
                    title: "RxExample",
                    message: message,
                    delegate: nil,
                    cancelButtonTitle: "OK"
                )
                alertView.show()
            }
            .addDisposableTo(disposeBag)
        //}
    }
    
    func dismissKeyboard(gr: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    
    /*
    // MARK: - Navigation
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    // Get the new view controller using segue.destinationViewController.
    // Pass the selected object to the new view controller.
    }
    */
    
}
