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
    
    typealias completionStringChunk = (_ success: Bool, _ error: Error?, _ result: String?) -> Void
    typealias completionJSONChunk = (_ success: Bool, _ error: Error?, _ result: JSON?) -> Void
    
    public static func fetchUserToken(developerToken: String, completion: @escaping completionStringChunk) {
        
        print("Start fetching User Token")
        
        let controller = SKCloudServiceController()
        controller.requestUserToken(forDeveloperToken: developerToken) { (userToken: String?, error: Error?) in
            if let musicUserToken = userToken {
                // Fetching SUCCEEDED
                print("Got AppleMusicUserToken Successfully: \(musicUserToken)")
                completion(true, nil, musicUserToken)
            } else {
                // Fetching FAILED
                guard let error = error else { return }
                print("Error Encountered!")
                print(error)
                print(error.localizedDescription)
                completion(false, error, nil)
            }
        }
    }
    
    public static func fetchUserStorefront(developerToken: String, userToken: String, completion: @escaping completionJSONChunk) {
        
        let urlRequest = AppleMusicRequestFactory.createGetUserStorefrontRequest(developerToken: developerToken, userToken: userToken)
        
        Alamofire.request(urlRequest)
            .responseJSON { response in
                
                print("fetchUserStorefront Request Response: \(response)")
                
                var statusCode = response.response?.statusCode
                if let error = response.result.error as? AFError {
                    
                    guard let status = statusCode else { return }
                    statusCode = handleResponseAFError(statusCode: status, error: error)
                    // handling Alamofire Error
                    completion(false, error, nil)
                    
                } else if let error = response.result.error as? URLError {
                    print("URLError occurred: \(error)")
                    // handling URLError
                    completion(false, error, nil)
                }
                
//                Status Code Returned by Apple Music server: https://developer.apple.com/documentation/applemusicapi/common_objects/http_status_codes
                
                if let statusCode = response.response?.statusCode {
                    print("Request Status Code: \(statusCode)")
                    let decodedStatus = handleResponseStatusCode(statusCode: statusCode)
                    
                    if decodedStatus.success {
                        print(decodedStatus.codeName)
                        print(decodedStatus.description)
                        completion(true, nil, JSON(response.result.value ?? "NA"))
                    } else {
                        print(decodedStatus.codeName)
                        print(decodedStatus.description)
                        // HTTP status code already printed out decodedStatus, error returned is nil
                        completion(false, nil, nil)
                    }
                    
                } else {
                    // No HTTP Status Code, report in console & error returned is nil
                    print("NO HTTP Status Code, Check Internet Availability and Retry Request")
                    completion(false, nil, nil)
                }
                
                
        }
        
    }
    
    // FIXME: -  This function has NOT been tested yet, possible to malfuntion or fail to work
    public static func fetchAllUserLibraryPlaylists(developerToken: String, userToken: String, completion: @escaping completionJSONChunk) {
        
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
    
    public static func fetchAllUserLibrarySongs(developerToken: String, userToken: String, completion: @escaping completionJSONChunk) {
        
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
    
    private static func handleResponseStatusCode(statusCode: Int) -> (success: Bool, codeName: String, description: String) {
        switch statusCode {
        case 200:
            return (true, "OK", "The request was successful; no errors or faults.")
        case 201:
            return (true, "Created", "Creation request was successful.")
        case 202:
            return (true, "Accepted", "Modification request was accepted but may not have completed.")
        case 204:
            return (true, "No Content", "Modification was successful, but there’s no content in the response.")
        case 301:
            return (false, "Moved Permanently", "Content may be available at a different URL.")
        case 302:
            return (false, "Found", "Content definitely available at a specific URL.")
        case 400:
            return (false, "Bad Request", "The request wasn’t accepted as formed.")
        case 401:
            let description401 = """
                The request wasn’t accepted because its authorization is missing or invalid due to an issue with the developer token.
                (For personal endpoints) Authorization issues may occur because the user wasn’t signed in or didn’t have a valid Apple Music subscription.
                (For music user token request) Developer token issues may occur because the token wasn’t received or was invalid. There could also be an error processing the request.
            """
            return (false, "Unauthorized", description401)
        case 403:
            let description403 = """
                The request wasn’t accepted due to an issue with the music user token or because it’s using incorrect authentication.
                (For personal endpoints) Authentication issues may occur if the account hasn’t accepted the Media and Apple Music privacy setting.
            """
            return (false, "Forbidden", description403)
        case 404:
            return (false, "Not Found", "The requested resource doesn’t exist.")
        case 405:
            return (false, "Method Not Allowed", "The method can’t be used for the request.")
        case 409:
            return (false, "Conflict", "A modification or creation request couldn’t be processed because there’s a conflict with the current state of the resource.")
        case 413:
            return (false, "Payload Too Large", "The body of the request is too large.")
        case 414:
            return (false, "URI Too Long", "The URI of the request is too long and won’t be processed.")
        case 429:
            return (false, "Too Many Requests", "The user has made too many requests. See Simulate the Too Many Requests Error.")
        case 500:
            return (false, "Internal Server Error", "There’s an error processing the request.")
        case 501:
            return (false, "Not Implemeneted", "Endpoint is currently unavailable and reserved for future use.")
        case 503:
            return (false, "Service Unavailable", "The service is currently unavailable to process requests.")
        default:
            return (false, "Unknown Status Code", "No Description Available.")
        }
    }
    
    private static func handleResponseAFError(statusCode: Int, error: AFError) -> Int {
        var status = error._code // statusCode private
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
                status = code
            }
        case .responseSerializationFailed(let reason):
            print("Response serialization failed: \(error.localizedDescription)")
            print("Failure Reason: \(reason)")
        }
        
        print("Underlying error: \(String(describing: error.underlyingError))")
        return status
    }
    
    
}
