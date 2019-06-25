//
//  Vimeo.swift
//  Bits
//
//  Created by Florian Kugler on 08-11-2018.
//

import Foundation
import Networking

let vimeo = Vimeo()

struct Video: Codable {
    struct Download: Codable {
        var width: Int
        var height: Int
        var link: URL
    }
    
    struct File: Codable {
        var quality: String
        var type: String
        var link: URL
    }
    
    var download: [Download]
    var files: [File]
}

extension Video {
    var hlsURL: URL? {
        return files.first { $0.quality == "hls" }?.link
    }
}


struct Vimeo {
    let base = URL(string: "https://api.vimeo.com")!
    let apiKey = env.vimeoAccessToken
    var headers: [String:String] {
        return [
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    func videoInfo(for videoId: Int) -> RemoteEndpoint<Video> {
        return RemoteEndpoint<Video>(json: .get, url: base.appendingPathComponent("videos/\(videoId)"), headers: headers)
    }
    
    func downloadURL(for videoId: Int) -> RemoteEndpoint<URL?> {
        return videoInfo(for: videoId).map { video in
            video.download.first { $0.width == 1920 }?.link
        }
    }
}
