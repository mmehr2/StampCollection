//
//  WebItemViewController.swift
//  
//
//  Created by Michael L Mehr on 7/8/15.
//
//

import UIKit
import WebKit

class WebItemViewController: UIViewController {

    var url: URL!
    
    var webView: WKWebView!

    override func loadView() {
        super.loadView()
        
        // programmatic use of WKWebView goes here
        // see http://www.kinderas.com/technology/2014/6/7/getting-started-with-wkwebview-using-swift-in-ios-8
        self.webView = WKWebView(frame: view.bounds)
        self.view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        // Do any additional setup after loading the view.
        if let url = url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    /*
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
