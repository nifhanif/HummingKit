//
//  AppleMusicInfoFetch.swift
//  HummingKit
//
//  Created by 唐子轩 on 2019/9/5.
//  Copyright © 2019 TonyTang. All rights reserved.
//

import Foundation
import CoreData
import StoreKit
import Alamofire
import SwiftyJSON

struct AppleMusicInfoFetch {
    
    static let userDefaults = UserDefaults.standard
    static let AppleMusicUserToken = "AppleMusicUserToken"
    
    // completionHandlers needs to pass back status & responseJSON
    
    public static func fetchUserToken(developerToken: String, completion: @escaping (_ success: Bool, _ error: Error?) -> Void) {
        print("Start fetching User Token")
        let controller = SKCloudServiceController()
        controller.requestUserToken(forDeveloperToken: developerToken) { (userToken: String?, error: Error?) in
            if let musicUserToken = userToken {
                print("Got AppleMusicUserToken Successfully: \(musicUserToken)")
                userDefaults.set(musicUserToken, forKey: AppleMusicUserToken)
                completion(true, nil)   // fetching succeeded (success = true, error = nil)
            } else {
                // Fetching FAILED
                guard let error = error else { return }
                print(error)
                completion(false, error)    // fetching failed (success = false, error = error), further handling required
            }
        }
    }
    
    public static func fetchUserStorefront(developerToken: String, userToken: String, completion: @escaping (_ success: Bool, _ error: Error?, _ result: JSON?) -> Void) {
        
        let urlRequest = AppleMusicRequestFactory.createGetUserStorefrontRequest(developerToken: developerToken, userToken: userToken)
        
        Alamofire.request(urlRequest)
            .responseJSON { response in
                
//                print("Request Response: \(response)")
                
                var statusCode = response.response?.statusCode
                if let error = response.result.error as? AFError {
                    statusCode = error._code // statusCode private
                    switch error {
                    case .invalidURL(let url):
                        print("Invalid URL: \(url) - \(error.localizedDescription)")
                    case .parameterEncodingFailed(let reason):
                        print("Parameter encoding failed: \(error.localizedDescription)")
                        print("Failure Reason: \(reason)")
                    case .multipartEncodingFailed(let reason):
                        print("Multipart encoding failed: \(error.localizedDescription)")
                        print("Failure Reason: \(reason)")
                    case .responseValidationFailed(let reason):
                        print("Response validation failed: \(error.localizedDescription)")
                        print("Failure Reason: \(reason)")
                        
                        switch reason {
                        case .dataFileNil, .dataFileReadFailed:
                            print("Downloaded file could not be read")
                        case .missingContentType(let acceptableContentTypes):
                            print("Content Type Missing: \(acceptableContentTypes)")
                        case .unacceptableContentType(let acceptableContentTypes, let responseContentType):
                            print("Response content type: \(responseContentType) was unacceptable: \(acceptableContentTypes)")
                        case .unacceptableStatusCode(let code):
                            print("Response status code was unacceptable: \(code)")
                            statusCode = code
                        }
                    case .responseSerializationFailed(let reason):
                        print("Response serialization failed: \(error.localizedDescription)")
                        print("Failure Reason: \(reason)")
                    }
                    print("Underlying error: \(String(describing: error.underlyingError))")
                    
                    completion(false, error, nil)  // fetching failed (success = false, error = error, result = nil)
                    
                } else if let error = response.result.error as? URLError {
                    print("URLError occurred: \(error)")
                    // handling URLError
                    completion(false, error, nil)  // fetching failed (success = false, error = error, result = nil)
                }
                
//                Status Code Returned by Apple Music API: https://developer.apple.com/documentation/applemusicapi/common_objects/http_status_codes
                print("Request Status Code: \(statusCode!)")
                
                
                completion(true, nil, JSON(response.result.value ?? "NA"))  // fetching succeeded (success = true, error = nil, result = JSON)
        }
        
    }
    
    // FIXME: -  This function has NOT been tested yet, possible to malfuntion or fail to work
    public static func fetchAllUserLibraryPlaylists(developerToken: String, userToken: String, completion: @escaping (_ success: Bool, _ error: Error?, _ result: JSON?) -> Void) {
        
        var allFullInfo: JSON = []
        var offset: String = "0"
        var finished: Bool = false
        
        func fetchPartialUserLibraryPlaylists(developerToken: String, userToken: String, Offset: String, completion: @escaping (_ partialInfo: JSON, _ nextOffset: String, _ finished: Bool) -> Void ) {
            
            let urlRequest = AppleMusicRequestFactory.createGetUserLibraryPlaylistsRequest(developerToken: developerToken, userToken: userToken, offset: Offset)
            
            var offsetIndexString: String = ""
            
            Alamofire.request(urlRequest)
                .responseJSON { response in
                    
                    let currentJson = JSON(response.result.value ?? "NA")
                    let playlistsInfoJson = currentJson["data"]
                    var isFinished = false
                    
                    if currentJson["next"].exists() {
                        // extract offsetIndexString from "next"
                        guard let next = currentJson["next"].string else { return }
                        offsetIndexString = self.offsetMatches(for: "(\\d{2,})", in: next)
                        
                        isFinished = false
                    } else {
                        isFinished = true
                    }
                    
                    // further refinement needed
                    
                    completion(playlistsInfoJson, offsetIndexString, isFinished)
            }
        }
        
        func goto() {
            switch finished {
            case false:
                print("unfinished")
                fetchPartialUserLibraryPlaylists(developerToken: developerToken, userToken: userToken, Offset: offset, completion: { (songsInfoJson, nextOffset, isFinished) in
                    do {
                        try allFullInfo = allFullInfo.merged(with: songsInfoJson)
                    } catch {
                        print(error)
                    }
                    offset = nextOffset
                    finished = isFinished
                    goto()
                })
            case true:
                print("finished")
                // further refinement needed
                
                //                completion(allFullInfo)
            }
        }
        
        goto()
        
//        let urlRequest = AppleMusicRequestFactory.createGetUserLibraryPlaylistsRequest(developerToken: developerToken, userToken: userToken)
//
//        Alamofire.request(urlRequest)
//            .responseJSON { response in
//                // further refinement needed
//
////                completion(JSON(response.result.value ?? "NA"))
//        }
        
    }
    
    public static func fetchAllUserLibrarySongs(developerToken: String, userToken: String, completion: @escaping (_ success: Bool, _ error: Error?, _ result: JSON?) -> Void) {
        
        var allFullInfo: JSON = []
        var offset: String = "0"
        var finished: Bool = false
        
        func fetchPartialUserLibrarySongs(developerToken: String, userToken: String, Offset: String, completion: @escaping (_ partialInfo: JSON, _ nextOffset: String, _ finished: Bool) -> Void ) {
            
            let urlRequest = AppleMusicRequestFactory.createGetUserLibrarySongsRequest(developerToken: developerToken, userToken: userToken, offset: Offset)
            
            var offsetIndexString: String = ""
            
            Alamofire.request(urlRequest)
                .responseJSON { response in
                    
                    let currentJson = JSON(response.result.value ?? "NA")
                    let songsInfoJson = currentJson["data"]
                    var isFinished = false
                    
                    if currentJson["next"].exists() {
                        // extract offsetIndexString from "next"
                        guard let next = currentJson["next"].string else { return }
                        offsetIndexString = self.offsetMatches(for: "(\\d{2,})", in: next)
                        
                        isFinished = false
                    } else {
                        isFinished = true
                    }
                    
                    // further refinement needed
                    
                    completion(songsInfoJson, offsetIndexString, isFinished)
            }
        }
        
        func goto() {
            switch finished {
            case false:
                print("unfinished")
                fetchPartialUserLibrarySongs(developerToken: developerToken, userToken: userToken, Offset: offset, completion: { (songsInfoJson, nextOffset, isFinished) in
                    do {
                        try allFullInfo = allFullInfo.merged(with: songsInfoJson)
                    } catch {
                        print(error)
                    }
                    offset = nextOffset
                    finished = isFinished
                    goto()
                })
            case true:
                print("finished")
                // further refinement needed
                
//                completion(allFullInfo)
            }
        }
        goto()
        
    }
    
    
    private static func offsetMatches(for regex: String, in text: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: text,
                                        range: NSRange(text.startIndex..., in: text))
            let finalResult = results.map {
                String(text[Range($0.range, in: text)!])
            }
            return finalResult.last ?? ""
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return ""
        }
    }
    
    
}