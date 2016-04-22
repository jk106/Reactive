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
import Bond
import Action

class GithubViewController: UIViewController {
    
    var library:Int!
    let rxViewModel = GithubSignupViewModel(
        API: GitHubDefaultAPI.sharedAPI,
        validationService: GitHubRxDefaultValidationService.sharedValidationService
    )
    
    let racViewModel = GithubRACViewModel(validationService: GitHubDefaultValidationService())
    
    let rkViewModel = GithubRKViewModel(validationService: GitHubDefaultValidationService())
    
    var disposeBag = RxSwift.DisposeBag()
    var rkDisposeBag = ReactiveKit.DisposeBag()
    
    var signupAction:ReactiveCocoa.CocoaAction!
    var bindingHelper: TableViewBindingHelper<NSDate>!
    
    let sbViewModel = GithubSBViewModel(validationService: GitHubDefaultValidationService())

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
            loadBond()
        default:
            loadRK()
        }
        let tapBackground = UITapGestureRecognizer(target: self, action: #selector(GithubViewController.dismissKeyboard(_:)))
        view.addGestureRecognizer(tapBackground)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func loadBond()
    {
        passwordOutlet.bnd_text.bindTo(sbViewModel.password)
        sbViewModel.validPassword.bindTo(passwordValidationOutlet.bnd_validationResult)
        
        repeatedPasswordOutlet.bnd_text.bindTo(sbViewModel.repeatedPassword)
        sbViewModel.validRepeat.bindTo(repeatedPasswordValidationOutlet.bnd_validationResult)
        
        usernameOutlet.bnd_text.bindTo(sbViewModel.username)
        sbViewModel.validUsername.bindTo(usernameValidationOutlet.bnd_validationResult)
        
        sbViewModel.signupEnabled.observeNew{
           enabled in
            self.signupOutlet.enabled = enabled
            self.signupOutlet.alpha = enabled ? 1.0 : 0.5
        }
        
        sbViewModel.signingIn.bindTo(signingUpOulet.bnd_animating)
        signupOutlet.bnd_tap.bindTo(sbViewModel.loginTaps)
        sbViewModel.signedIn.skip(1).observe{
            result in
            let message = result ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
            self.showMessage(message)
        }
        sbViewModel.dates.lift().bindTo(tableView){ indexPath, dates, tableView in
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.LongStyle
            formatter.timeStyle = .MediumStyle
            cell.textLabel?.text = formatter.stringFromDate(dates[indexPath.section][indexPath.row])
            return cell
        }
    }
    
    func loadRK()
    {
        passwordOutlet.rText.bindTo(rkViewModel.password)
        rkViewModel.validPassword.bindTo(passwordValidationOutlet.rValidationResult)
        
        repeatedPasswordOutlet.rText.bindTo(rkViewModel.repeatedPassword)
        rkViewModel.validRepeat.bindTo(repeatedPasswordValidationOutlet.rValidationResult)
        
        usernameOutlet.rText.bindTo(rkViewModel.username)
        rkViewModel.validUsername.bindTo(usernameValidationOutlet.rValidationResult)
        
        rkViewModel.signupEnabled.observeNext
            {
                enabled in
                self.signupOutlet.enabled = enabled
                self.signupOutlet.alpha = enabled ? 1.0 : 0.5
        }.disposeIn(rkDisposeBag)
        
        rkViewModel.signingIn.bindTo(signingUpOulet.rAnimating)
        signupOutlet.rTap.bindTo(rkViewModel.loginTaps)
        rkViewModel.signedIn.skip(1).observeNext
            {
                result in
                let message = result ? "Mock: Signed in to GitHub." : "Mock: Sign in to GitHub failed"
                self.showMessage(message)
        }.disposeIn(rkDisposeBag)
        rkViewModel.dates.bindTo(tableView){ indexPath, dates, tableView in
            let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
            let formatter = NSDateFormatter()
            formatter.dateStyle = NSDateFormatterStyle.LongStyle
            formatter.timeStyle = .MediumStyle
            cell.textLabel?.text = formatter.stringFromDate(dates[indexPath.row])
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
        rxViewModel.dates.asObservable().bindTo(tableView.rx_itemsWithCellIdentifier("Cell")){ (row, element, cell) in
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
        let alert = UIAlertController(
            title: "RxExample",
            message: message,
            preferredStyle: UIAlertControllerStyle.Alert
        )
        let cancelAction = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion: nil)
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
