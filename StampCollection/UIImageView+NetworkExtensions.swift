//
//  UIImageView+NetworkExtensions.swift
//  StampCollection
//
//  Created by Michael L Mehr on 11/5/15.
//  Copyright © 2015 Michael L. Mehr. All rights reserved.
//

import UIKit

// MARK: image downloading
// clever hack from here: http://stackoverflow.com/questions/24231680/swift-loading-image-from-url
// NOTE: had to update it to use NSURLSession() due to iOS9 deprecations
// NOTE: to make this work for IOS9+, need to add stuff to Info.plist from here: http://stackoverflow.com/questions/31254725/transport-security-has-blocked-a-cleartext-http/32560433#32560433
/*
NOTE: THIS IS A HACK! WE REALLY NEED TO CHANGE THINGS TO USE HTTPS: IN THE URLS INSTEAD.. HOW?
<key>NSAppTransportSecurity</key>
<dict>
<key>NSAllowsArbitraryLoads</key>
<false/>
<key>NSExceptionDomains</key>
<dict>
<key>bait-tov.com</key>
<dict>
<key>NSIncludesSubdomains</key>
<true/>
<key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
<true/>
<key>NSTemporaryExceptionMinimumTLSVersion</key>
<string>TLSv1.1</string>
</dict>
<key>judaicasales.com</key>
<dict>
<key>NSIncludesSubdomains</key>
<true/>
<key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
<true/>
<key>NSTemporaryExceptionMinimumTLSVersion</key>
<string>TLSv1.1</string>
</dict>
</dict>
</dict>
*/
public typealias CompHandler = ((UIImage?, forURL: NSURL) -> Void)
private var completionHandlersForImageTask: [String:CompHandler] = [:]
private var debugging = false // turn on to get debug printouts
// a pure URL index is not enough, we get two or three simultaneous requests for the same pic url in real life to different views
// SO.. we need to get a unique hash from the URL and if it's in the table already, we need to extend it until we find one that's not
// this could cause a race too, unless we can insure that the hashing is atomic
// still, it should really only need to test once, or at most twice, so maybe it's okay...
private func installHandler(url: NSURL, completion: CompHandler) -> String {
    var code = url.path!
    repeat {
        guard completionHandlersForImageTask[code] != nil else {
            completionHandlersForImageTask[code] = completion // this is the final case, not in the DB
            if debugging { print("Installed handler for code \(code)") }
            return code
        }
        code += ("X") // try it with another X on the end, until we have a hit
    } while true
}

extension UIImageView {
    public func imageFromUrlString(urlString: String) {
        if let url = NSURL(string: urlString) {
            imageFromUrl(url)
        }
    }
    public func imageFromUrl(url: NSURL?, completion: CompHandler? = nil) {
        if let url = url, completion = completion {
            if debugging { print("Requesting pic file at \(url)") }
            let code = installHandler(url, completion: completion)
            let task = NSURLSession.sharedSession().dataTaskWithURL(url) { (data, response, error) in
                if let error = error {
                    if debugging { print("Pic data received with error \(error)") }
                } else {
                    let image = UIImage(data: data!)
                    if debugging { print("Pic data received with image \(image)") }
                    if let completion = completionHandlersForImageTask[code] {
                        NSOperationQueue.mainQueue().addOperationWithBlock() {
                            completion(image, forURL: url)
                            completionHandlersForImageTask[code] = nil
                            if debugging { print("Removed handler for code \(code)") }
                        }
                    }
                }
            }
            task.resume()
        }
    }
}
