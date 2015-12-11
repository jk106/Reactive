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
        static var ValidationResultKey = "r_ValidatioNResultKey"
    }
    
    var rValidationResult: Observable<ValidationResult?> {
        if let rValidationResult: AnyObject = objc_getAssociatedObject(self, &AssociatedKeys.ValidationResultKey) {
            return rValidationResult as! Observable<ValidationResult?>
        } else {
            let rValidationResult = Observable<ValidationResult?>(ValidationResult.Empty)
            objc_setAssociatedObject(self, &AssociatedKeys.ValidationResultKey, rValidationResult, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            rValidationResult.observe(on: ImmediateOnMainExecutionContext) { [weak self] (result: ValidationResult?) in
                    self?.textColor = result!.textColor
                    self?.text = result!.description
            }
            return rValidationResult
        }
    }
}
