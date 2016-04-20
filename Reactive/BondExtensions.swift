//
//  BondExtensions.swift
//  Reactive
//
//  Created by Juan Chaparro on 20/04/16.
//  Copyright © 2016 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit
import Bond

extension UILabel {
    private struct AssociatedKeys {
        static var ValidationResultKey = "bnd_ValidationResult"
    }
    
    var bnd_validationResult: Observable<ValidationResult?> {
        if let bnd_validationResult: AnyObject = objc_getAssociatedObject(self, &AssociatedKeys.ValidationResultKey) {
            return bnd_validationResult as! Observable<ValidationResult?>
        } else {
            let bnd_validationResult = Observable<ValidationResult?>(ValidationResult.Empty)
            objc_setAssociatedObject(self, &AssociatedKeys.ValidationResultKey, bnd_validationResult, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            bnd_validationResult.observeNew { [weak self] (result: ValidationResult?) in
                self?.textColor = result!.textColor
                self?.text = result!.description
            }
            
            return bnd_validationResult
        }
    }
}