import Foundation
import TinyNetworking

struct Blogpost: Codable {
    var title: String
    var url: String
    var episode: Int?
    var collection: String?
    var synopsis: String?
    var date: Date
    
    var fullURL: URL {
        return Objcio.shared.base.appendingPathComponent(url)
    }
}

fileprivate let decoder: JSONDecoder = {
    var d = JSONDecoder()
    d.dateDecodingStrategy = .formatted(DateFormatter.iso8601WithTrailingZ)
    return d
}()

struct Objcio {
    let base = URL(string: "https://www.objc.io")!
    static let shared = Objcio()
    

    var blogPosts: Endpoint<[Blogpost]> {
        return Endpoint(json: .get, url: base.appendingPathComponent("api/posts.json"), decoder: decoder)
    }
}
