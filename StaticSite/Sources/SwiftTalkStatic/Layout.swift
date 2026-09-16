import Foundation

/// Mirrors the original view templates using the existing application.css.
/// Public pages have no session-dependent UI.
struct Renderer {
    var content: Content
    var baseURL: URL
    var assets: URL

    func absolute(_ path: String) -> String {
        URL(string: path, relativeTo: baseURL)!.absoluteURL.absoluteString
    }

    func svg(_ name: String, classes: String) -> String {
        guard let source = try? String(contentsOf: assets.appendingPathComponent("images/\(name)"), encoding: .utf8) else { return "" }
        return source.replacingOccurrences(of: "<svg ", with: "<svg aria-hidden=\"true\" class=\"\(classes)\" ")
    }

    func page(title: String, path: String, description: String, body: String, image: String? = nil, player: Bool = false, theme: String = "default", searchMetadata: String = "") -> String {
        let nav = [("/", "Swift Talk"), ("https://www.objc.io/books", "Books"), ("https://www.objc.io/issues", "Issues"), ("https://www.objc.io/workshops/swiftui", "SwiftUI Workshop")].map { url, label in
            "<li class=\"flex mr+\"><a href=\"\(url)\" class=\"flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration\"><span>\(label)</span></a></li>"
        }.joined()
        return """
        <!doctype html>
        <html lang="en"><head>
          <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
          <title>\(title.escaped) - Swift Talk - objc.io</title>
          <meta name="description" content="\(description.escaped)">
          \(searchMetadata)
          <link rel="canonical" href="\(absolute(path).escaped)">
          <meta property="og:title" content="\(title.escaped)"><meta property="og:description" content="\(description.escaped)">
          <meta property="og:type" content="\(player ? "video.episode" : "website")"><meta property="og:url" content="\(absolute(path).escaped)">
          \(image.map { "<meta property=\"og:image\" content=\"\($0.escaped)\">" } ?? "")
          <link rel="icon" href="/favicon.ico"><link rel="alternate" type="application/rss+xml" title="Swift Talk RSS" href="/episodes.rss">
          <link rel="stylesheet" href="/assets/stylesheets/application.css"><link rel="stylesheet" href="/assets/static-site.css">
          \(player ? "<script defer src=\"https://player.vimeo.com/api/player.js\"></script>" : "")
          <script defer src="/assets/static-site.js"></script>
        </head><body class="theme-\(theme)">
          <a class="skip-link" href="#main">Skip to content</a>
          <header class="bgcolor-white"><div class="height-3 flex scroller"><div class="container-h flex-grow flex">
            <a class="flex-none mr++ flex" href="https://www.objc.io" aria-label="objc.io">\(svg("logo.svg", classes: "block logo logo--themed height-auto"))</a>
            <nav class="flex flex-grow" aria-label="Main navigation"><ul class="flex flex-auto">\(nav)</ul></nav>
          </div></div></header>
          <main id="main">\(body)</main>
          \(footer)
        </body></html>
        """
    }

    var footer: String {
        func column(_ title: String, _ items: [(String, String)]) -> String {
            "<div class=\"col width-1/3\"><p class=\"mb\"><span class=\"smallcaps color-gray-40\">\(title)</span></p><ul class=\"stack-\">" + items.map { url, label in
                "<li><a class=\"no-decoration color-gray-60 hover-color-black\" href=\"\(url)\">\(label.escaped)</a></li>"
            }.joined() + "</ul></div>"
        }
        return """
        <footer><div class="container"><div class="cols m-|stack++">
          <div class="col m+|width-1/2"><a class="inline-block mb" href="https://www.objc.io/" aria-label="objc.io">\(svg("logo.svg", classes: "logo logo--themed"))</a><p class="lh-125 color-gray-40">objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development.</p></div>
          <nav class="col width-full m+|width-1/2" aria-label="Footer"><div class="cols">
            \(column("Learn", [("/", "Swift Talk"), ("https://www.objc.io/books", "Books"), ("https://www.objc.io/workshops", "Workshops"), ("https://www.objc.io/issues", "Issues")]))
            \(column("Follow", [("https://www.objc.io/blog", "Blog"), ("/episodes.rss", "RSS"), ("https://twitter.com/objcio", "Twitter"), ("https://www.youtube.com/objcio", "YouTube")]))
            \(column("More", [("https://www.objc.io/about", "About"), ("mailto:mail@objc.io", "Email"), ("https://www.objc.io/imprint", "Imprint & Legal")]))
          </div></nav>
        </div></div></footer>
        """
    }

    func pageHeader(_ title: String) -> String {
        "<header class=\"bgcolor-blue pattern-shade\"><div class=\"container\"><a href=\"/\" class=\"ms1 inline-block no-decoration lh-100 pb- color-white opacity-70 hover-underline\">Swift Talk</a><h1 class=\"color-white bold ms4\">\(title.escaped)</h1></div></header>"
    }

    var notFound: String {
        page(title: "Page not found", path: "/404.html", description: "Find an episode in the Swift Talk archive.", body: "\(pageHeader("Page not found"))<div class=\"container lh-135\"><p>This page isn’t in the archive.</p><p class=\"mt\"><a class=\"color-blue\" href=\"/episodes\">Browse all episodes →</a></p></div>")
    }

    func redirect(to path: String) -> String {
        """
        <!doctype html><html lang="en"><head><meta charset="utf-8"><title>Swift Talk</title><link rel="canonical" href="\(absolute(path).escaped)"><meta http-equiv="refresh" content="0;url=\(path.escaped)"></head><body><a id="redirect" href="\(path.escaped)">Continue to the episode</a><script>location.replace(document.getElementById('redirect').getAttribute('href') + location.search + location.hash);</script></body></html>
        """
    }

    var rss: String {
        let items = content.episodes.map { episode in
            let link = absolute(episode.path).escaped
            return "<item><guid>\(link)</guid><title>\(content.fullTitle(episode).escaped)</title><link>\(link)</link><pubDate>\(formattedDate(episode.releaseAt, format: "EEE, dd MMM yyyy HH:mm:ss Z"))</pubDate><description>\(episode.synopsis.escaped)</description></item>"
        }.joined()
        return """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>Swift Talk — objc.io</title><link>\(baseURL.absoluteString.escaped)</link><description>Every Swift Talk episode, freely available with full transcripts.</description><language>en</language><atom:link href="\(absolute("/episodes.rss").escaped)" rel="self" type="application/rss+xml"/>\(items)</channel></rss>
        """
    }

    var sitemap: String {
        let paths = ["/", "/episodes", "/collections"] + content.collections.map(\.path) + content.episodes.map(\.path)
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?><urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">" + paths.map { "<url><loc>\(absolute($0).escaped)</loc></url>" }.joined() + "</urlset>"
    }
}
