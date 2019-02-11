//
//  Vimeo.swift
//  Bits
//
//  Created by Florian Kugler on 08-11-2018.
//

import Foundation
import Networking

let vimeo = Vimeo()

struct Vimeo {
    let base = URL(string: "https://api.vimeo.com")!
    let apiKey = env.vimeoAccessToken
    var headers: [String:String] {
        return [
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    func downloadURL(for videoId: Int) -> RemoteEndpoint<URL?> {
        struct Video: Codable {
            var download: [Download]
        }
        struct Download: Codable {
            var width: Int
            var height: Int
            var link: URL
        }

        return RemoteEndpoint<Video>(json: .get, url: base.appendingPathComponent("videos/\(videoId)"), headers: headers).map { video in
            video.download.first { $0.width == 1920 }?.link
        }
    }
}
