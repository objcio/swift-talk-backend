import Foundation

let env = Env()
let headers = [
    "Authorization": "Bearer \(env["ACCESS_TOKEN"])"
]


struct Page<A>: Codable where A: Codable {
    var total: Int?
    var page: Int
    var per_page: Int
    var paging: Paging
    var data: [A]
}

struct Video: Codable {
    var uri: String
    var name: String
    var description: String?
    var link: URL
    var duration: TimeInterval
    var width: Int
    var height: Int
    var language: String?
    var pictures: Pictures
    
    struct Pictures: Codable {
        var uri: String?
        var active: Bool
        var type: String
        var sizes: [Picture]
    }
    
    struct Picture: Codable {
        var width: Int
        var height: Int
        var link: URL
        var link_with_play_button: URL
    }
}


struct Paging: Codable {
    var next: String?
    var previous: String?
    var first: String
    var last: String
}

extension Page  {
    var next: RemoteEndpoint<Page<A>>? {
        return paging.next.map { n in
            let url = URL(string: "https://api.vimeo.com" + n)!
            print(url)
            return RemoteEndpoint(get: url, accept: nil, headers: headers, query: [:], parse: { data in
                return try! JSONDecoder().decode(Page<A>.self, from: data)
            })
        }
    }
}

let firstPage = RemoteEndpoint<Page<Video>>(get: URL(string: "https://api.vimeo.com/me/videos")!, accept: nil, headers: headers, query: [:], parse: { data in
    let decoder = JSONDecoder()
    return try! decoder.decode(Page<Video>.self, from: data)
})

func loadAll<A>(request: RemoteEndpoint<Page<A>>, accum: [A] = [], onComplete: @escaping ([A]) -> ()) {
    URLSession.shared.load(request, callback: { (data: Page<A>?) -> () in
        guard let d = data else { fatalError() }
        if let p = data?.next {
            loadAll(request: p, accum: accum + d.data, onComplete: onComplete)
        } else {
            onComplete(accum + d.data)
        }
    })

}

loadAll(request: firstPage, onComplete: {
    let data = try! JSONEncoder().encode($0)
    try! data.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath + "/videos.json"))
})

sleep(100)
