//
//  GithubViewController.swift
//  Reactive
//
//  Created by Juan Camilo Chaparro Marroquin on 12/10/15.
//  Copyright © 2015 Juan Camilo Chaparro Marroquin. All rights reserved.
//

import UIKit

class GithubViewController: UIViewController {
    
    var library:Int!
    var viewModel:AnyObject!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch(library){
        case 1:
            print(self.title)
        case 2:
            print(self.title)
        case 3:
            print(self.title)
        default:
            print(self.title)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
