//
//  TableViewBindingHelper.swift
//  ReactiveSwiftFlickrSearch
//
//  Created by Colin Eberhardt on 15/07/2014.
//  Copyright (c) 2014 Colin Eberhardt. All rights reserved.
//

import Foundation
import ReactiveCocoa
import UIKit
import Result

@objc protocol ReactiveView {
    func bindViewModel(viewModel: AnyObject)
}

class TableViewBindingHelper<T: AnyObject> : NSObject {
    
    //MARK: Properties
    
    var delegate: UITableViewDelegate?
    
    private let tableView: UITableView
    private let dataSource: DataSource
    
    //MARK: Public API
    
    init(tableView: UITableView, sourceSignal: SignalProducer<[T], NoError>) {
        self.tableView = tableView
        dataSource = DataSource(data: [AnyObject]())
        
        super.init()
        
        sourceSignal.startWithNext{
            data in
            self.dataSource.data = data.map({ $0 as AnyObject })
            self.tableView.reloadData()
        }
        
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
    }
    
}

class DataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    
    var data: [AnyObject]
    
    
    init(data: [AnyObject]) {
        self.data = data
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
        let row = indexPath.row
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.LongStyle
        formatter.timeStyle = .MediumStyle
        cell.textLabel?.text = formatter.stringFromDate(data[row] as! NSDate)
        return cell
    }
}
