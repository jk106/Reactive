//
//  BindingExtensions.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 12/6/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

extension ValidationResult: CustomStringConvertible {
    var description: String {
        switch self {
        case let .OK(message):
            return message
        case .Empty:
            return ""
        case .Validating:
            return "validating ..."
        case let .Failed(message):
            return message
        }
    }
}

extension Observable {
    func doOnNext(closure: Element -> Void) -> Observable<Element> {
        return doOn { (event: Event) in
            switch event {
            case .Next(let value):
                closure(value)
            default: break
            }
        }
    }
    
    func doOnCompleted(closure: () -> Void) -> Observable<Element> {
        return doOn { (event: Event) in
            switch event {
            case .Completed:
                closure()
            default: break
            }
        }
    }
    
    func doOnError(closure: ErrorType -> Void) -> Observable<Element> {
        return doOn { (event: Event) in
            switch event {
            case .Error(let error):
                closure(error)
            default: break
            }
        }
    }
}

struct ValidationColors {
    static let okColor = UIColor(red: 138.0 / 255.0, green: 221.0 / 255.0, blue: 109.0 / 255.0, alpha: 1.0)
    static let errorColor = UIColor.redColor()
}

extension ValidationResult {
    var textColor: UIColor {
        switch self {
        case .OK:
            return ValidationColors.okColor
        case .Empty:
            return UIColor.blackColor()
        case .Validating:
            return UIColor.blackColor()
        case .Failed:
            return ValidationColors.errorColor
        }
    }
}

extension UILabel {
    var ex_validationResult: AnyObserver<ValidationResult> {
        return AnyObserver { [weak self] event in
            switch event {
            case let .Next(result):
                self?.textColor = result.textColor
                self?.text = result.description
            case let .Error(error):
                print(error)
            case .Completed:
                break
            }
        }
    }
}