//
//  Model.swift
//  Bits
//
//  Created by Chris Eidhof on 06.08.18.
//

import Foundation

let teamDiscount = 30

struct Slug<A>: Codable, Equatable, RawRepresentable {
    let rawValue: String
}

struct Id<A>: RawRepresentable, Codable, Equatable {
    var rawValue: String
}

struct Guest: Codable, Equatable {
    var name: String
    // todo
}

struct Episode_Old: Codable, Equatable {
    var collection: Id<Collection>?
    var created_at: Int
    var furthest_watched: Double?
    var id: Id<Episode>
    var media_duration: TimeInterval?
    var media_url: URL?
    var name: String?
    var number: Int
    var play_position: Double?
    var poster_url: URL?
    var released_at: TimeInterval?
    var sample: Bool
    var sample_duration: TimeInterval?
    var season: Int
    var small_poster_url: URL?
    var subscription_only: Bool
    var synopsis: String
    var title: String
    var updated_at: Int
    var guests: [Guest]?
}

struct Episode: Codable, Equatable {
    var collections: [String]?
    var created_at: String
    var id: Id<Episode>
    var mailchimp_campaign_id: String?
    var media_duration: TimeInterval?
    var media_src: String?
    var media_version: Int
    var name: String
    var number: Int
    var poster_uid: String?
    var release_at: String?
    var released: Bool
    var sample_src: String?
    var sample_duration: TimeInterval?
    var sample_version: Int
    var season: Int
//    var small_poster_url: URL?
    var subscription_only: Bool
    var synopsis: String
    var title: String
    var updated_at: String?
    var video_id: String?
//    var guests: [Guest]?
}

extension Episode {
    var fullTitle: String {
        return title // todo
    }
    var releasedAt: Date? {
        let formatter = DateFormatter.iso8601
        return release_at.flatMap { formatter.date(from: $0) }
    }
    
    var poster_url: URL? {
        // todo
        return URL(string: "https://d2sazdeahkz1yk.cloudfront.net/assets/media/W1siZiIsIjIwMTgvMDYvMTQvMTAvMDEvNDEvYjQ1Njc3YWQtNDRlMS00N2E1LWI5NDYtYWFhOTZiOTYxOWM4LzExMSBEZWJ1Z2dlciAzLmpwZyJdLFsicCIsInRodW1iIiwiNTkweDI3MCMiXV0?sha=bb0917beee87a929")
    }
    
    var media_url: URL? {
        return URL(string: "https://d2sazdeahkz1yk.cloudfront.net/videos/5dbf3160-fb5b-4e5a-88da-3163ea09883b/1/hls.m3u8")
    }
}


struct Collection: Codable, Equatable {
    var id: Id<Collection>
    var artwork: String // todo this is a weird kind of URL we get from JSON
    var description: String
    var title: String
    var episodes_count: Int // todo compute
    var total_duration: TimeInterval // todo compute
}

extension Collection {
    var new: Bool {
        return false // todo
    }
}
