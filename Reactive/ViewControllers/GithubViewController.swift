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
import ReactiveUIKit
import ReactiveKit
import Action

class GithubViewController: UIViewController {
    
    var library:Int!
    let rxViewModel = GithubSignupViewModel(
        API: GitHubDefaultAPI.sharedAPI,
        validationService: GitHubDefaultValidationService.sharedValidationService
    )
    
    let racViewModel = GithubRACViewModel(validationService: GitHubRACDefaultValidationService())
    
    let rkViewModel = GithubRKViewModel(validationService: GitHubRACDefaultValidationService())
    
    var disposeBag = RxSwift.DisposeBag()
    
    var signupAction:ReactiveCocoa.CocoaAction!
    var bindingHelper: TableViewBindingHelper<NSDate>!
    
    @IBOutlet weak var usernameOutlet: UITextField!
    @IBOutlet weak var usernameValidationOutlet: UILabel!
    
    @IBOutlet weak var passwordOutlet: UITextField!
    @IBOutlet weak var passwordValidationOutlet: UILabel!
    
    @IBOutlet weak var repeatedPasswordOutlet: UITextField!
    @IBOutlet weak var repeatedPasswordValidationOutlet: UILabel!
    
    @IBOutlet weak var signupOutlet: UIButton!
    @IBOutlet weak var signingUpOulet: UIActivityIndicatorView!
    
    @IBOutlet weak var tableView: UITableView!
    
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
            loadRK()
        }
        let tapBackground = UITapGestureRecognizer(target: self, action: Selector("dismissKeyboard:"))
        view.addGestureRecognizer(tapBackground)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadRK()
    {
        passwordOutlet.rText.bindTo(rkViewModel.password)
        rkViewModel.validPassword.bindTo(passwordValidationOutlet.rValidationResult)
        
        repeatedPasswordOutlet.rText.bindTo(rkViewModel.repeatedPassword)
        rkViewModel.validRepeat.bindTo(repeatedPasswordValidationOutlet.rValidationResult)
        
        usernameOutlet.rText.throttle(0.5, on: Queue.main).bindTo(rkViewModel.username)
        rkViewModel.validUsername.bindTo(usernameValidationOutlet.rValidationResult)
        
        rkViewModel.signupEnabled.observe
            {
                enabled in
                self.signupOutlet.enabled = enabled
                self.signupOutlet.alpha = enabled ? 1.0 : 0.5
        }
        
        rkViewModel.signingIn.bindTo(signingUpOulet.rAnimating)
        signupOutlet.rTap.bindTo(rkViewModel.loginTaps)
        rkViewModel.signedIn.skip(1).observe
            {
                result in
                let message = result ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
                self.showMessage(message)
        }
        rkViewModel.dates.bindTo(tableView){ indexPath, dates, tableView in
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
            let row = indexPath.row
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.LongStyle
            formatter.timeStyle = .MediumStyle
            cell.textLabel?.text = formatter.stringFromDate(dates[row])
            return cell
        }
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
        racViewModel.loginTaps.executing.producer.start(Observer { [weak self] event in
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
        racViewModel.loginTaps.values.observeOn(UIScheduler()).observeNext
            {_ in
                self.showMessage("Mock: Signed in to GitHub.")
        }
        
        racViewModel.loginTaps.errors.observeOn(UIScheduler()).observeNext
            {_ in
                self.showMessage("Mock: Sign in to GitHub failed")
        }
        bindingHelper = TableViewBindingHelper(tableView: tableView, sourceSignal: self.racViewModel.dates.producer)
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
        
        signupOutlet.rx_action = rxViewModel.signedIn
        // }
        
        rxViewModel.signedIn.executing.bindTo(signingUpOulet.rx_animating)
            .addDisposableTo(disposeBag)
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
        
        rxViewModel.errors
            .subscribeNext { signedIn in
                self.showMessage(signedIn)
            }
            .addDisposableTo(disposeBag)
        
        rxViewModel.success
            .subscribeNext { signedIn in
                self.showMessage(signedIn)
            }
            .addDisposableTo(disposeBag)
        //}
        rxViewModel.dates.bindTo(tableView.rx_itemsWithCellIdentifier("Cell")){ (row, element, cell) in
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.LongStyle
            formatter.timeStyle = .MediumStyle
            cell.textLabel?.text = formatter.stringFromDate(element)
            }.addDisposableTo(disposeBag)
    }
    
    func dismissKeyboard(gr: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    
    func showMessage(message: String)
    {
        let alertView = UIAlertView(
            title: "RxExample",
            message: message,
            delegate: nil,
            cancelButtonTitle: "OK"
        )
        alertView.show()
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
