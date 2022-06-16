//
//  ViewController.swift
//  coSwiftDemo
//
//  Copyright © 2018 Alibaba Group Holding Limited All rights reserved.
//
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.

import UIKit
import coswift

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        co_launch {
            let str = try DataService.shared.fetchWeatherData()
            print("\(str)")
        }
        
        let queue = DispatchQueue(label: "MyQueue")
        co_launch(queue: queue) {
            print("hehe")
        }
        
        co_launch(stackSize: 128 * 1024) {
            print("haha")
        }
        
        
    }


}

