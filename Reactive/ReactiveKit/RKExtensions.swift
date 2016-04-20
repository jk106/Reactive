//
//  RKExtensions.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/11/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import ReactiveKit

extension UILabel {
    
    private struct AssociatedKeys {
        static var ValidationResultKey = "r_ValidationResultKey"
    }
    
    var rValidationResult: Property<ValidationResult?> {
        if let rValidationResult: AnyObject = objc_getAssociatedObject(self, &AssociatedKeys.ValidationResultKey) {
            return rValidationResult as! Property<ValidationResult?>
        } else {
            let rValidationResult = Property<ValidationResult?>(ValidationResult.Empty)
            objc_setAssociatedObject(self, &AssociatedKeys.ValidationResultKey, rValidationResult, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            rValidationResult.observeIn(ImmediateOnMainExecutionContext).observeNext { [weak self] (result: ValidationResult?) in
                    self?.textColor = result!.textColor
                    self?.text = result!.description
            }.disposeIn(rBag)
            return rValidationResult
        }
    }
}
