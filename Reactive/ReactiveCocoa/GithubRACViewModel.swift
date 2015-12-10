//
//  GithubRACViewModel.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import ReactiveCocoa

class GithubRACViewModel {
    
    private let API: GitHubAPI
    private let validationService: GitHubRACValidationService
    
    // inputs {
    
    let username = MutableProperty<String>("")
    let password = MutableProperty<String>("")
    let repeatedPassword = MutableProperty<String>("")
    
    //outputs
    let validatingUsername = MutableProperty<Bool>(false)
    let validUsername = MutableProperty<Bool>(false)
    let validPassword = MutableProperty<String>("")
    let validPasswordColor = MutableProperty<UIColor>(ValidationColors.okColor)
    let validRepeat = MutableProperty<String>("")
    let validRepeatColor = MutableProperty<UIColor>(ValidationColors.okColor)
    let signingIn = MutableProperty<Bool>(false)
    
    init(API: GitHubAPI, validationService: GitHubRACValidationService) {
        self.API = API
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
                    self.validPassword.value = response.description
                    self.validPasswordColor.value = response.textColor
            }))
        self.repeatedPassword.producer.combineLatestWith(self.password.producer)
            .map{p1,p2 in
                return self.validationService.validateRepeatedPassword(p1, repeatedPassword: p2)
        }
            .observeOn(QueueScheduler.mainQueueScheduler).start(Observer(failed: {
                print("Error \($0)")
                },
                next: {
                    response in
                    self.validRepeat.value = response.description
                    self.validRepeatColor.value = response.textColor
            }))
        /**self.username.producer.on(next: {_ in self.validatingUsername.value = true})
        .flatMap(FlattenStrategy.Latest) { text in
        SignalProducer<Bool, NSError> {
        sink, disposable in
        let result:Bool = self.API
        self.validUsername.value = result
        if !result {sink.sendFailed(GithubError.InvalidUser.toError())}
        }
        }
        .observeOn(QueueScheduler.mainQueueScheduler).start(Observer(failed: {
        print("Error \($0)")
        },
        next: {
        response in
        self.validatingUsername.value = false
        }))*/
    }
    
}
