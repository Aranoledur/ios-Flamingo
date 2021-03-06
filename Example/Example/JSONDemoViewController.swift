//
//  JSONDemoViewController.swift
//  Example
//
//  Created by Георгий Касапиди on 16.05.16.
//  Copyright © 2016 ELN. All rights reserved.
//

import UIKit
import Alamofire
import Flamingo

class JSONDemoViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "JSON Demo"
        
        textView.textContainerInset = UIEdgeInsetsMake(20, 20, 20, 20)
        
        setupNetwork()
    }
    
    @IBAction func getRealDataTapped() {
        loadUsersUsingMock(false)
    }
    
    @IBAction func useMockDataTapped() {
        loadUsersUsingMock(true)
    }
    
    // MARK: Network
    
    fileprivate var networkClient: NetworkClient!
    
    fileprivate func setupNetwork() {
        let configuration = NetworkDefaultConfiguration(baseURL: "http://jsonplaceholder.typicode.com/", useMocks: true, debugMode: true)
        let cacheManager = NetworkDefaultOfflineCacheManager(cacheName: "network_cache")
        
        networkClient = NetworkDefaultClient(configuration: configuration, offlineCacheManager: cacheManager)
    }
    
    fileprivate func loadUsersUsingMock(_ useMock: Bool) {
        if loadingIndicator.isAnimating {
            return
        }
        
        loadingIndicator.startAnimating()
        
        let request = UsersRequest(useMock: useMock)
        
        networkClient.sendRequest(request) { (users, error, context) in
            let json = users?.toJSONString(prettyPrint: true)
            
            self.textView.text = json
            
            self.loadingIndicator.stopAnimating()
        }
    }
}
