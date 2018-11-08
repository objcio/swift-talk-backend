//
//  Vimeo.swift
//  Bits
//
//  Created by Florian Kugler on 08-11-2018.
//

import Foundation


struct Vimeo {
    struct Video: Codable {
        struct Download: Codable {
            var width: Int
            var height: Int
            var link: URL
        }
        
        var download: [Download]
    }

    let base = URL(string: "https://api.vimeo.com")!
    let apiKey: String
    var headers: [String:String] {
        return [
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func downloadURL(for videoId: Int) -> RemoteEndpoint<URL?> {
        return RemoteEndpoint<Vimeo.Video>(get: base.appendingPathComponent("videos/\(videoId)"), headers: headers).map { video in
            video.download.first { $0.width == 1920 }?.link
        }
    }
}
