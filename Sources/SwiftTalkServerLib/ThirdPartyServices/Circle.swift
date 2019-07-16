//
//  Circle.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-11-2018.
//

import Foundation
import TinyNetworking

let circle = Circle()

struct Circle {
    let base = URL(string: "https://circleci.com/api/v1.1/")!
    var apiKey = env.circleApiKey
    
    var triggerMainSiteBuild: Endpoint<()> {
        let url = base.appendingPathComponent("project/github/objcio/website/tree/master")
        return Endpoint<()>(.post, url: url, query: ["circle-token": apiKey])
    }
}
