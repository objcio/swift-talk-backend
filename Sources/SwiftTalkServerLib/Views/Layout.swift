//
//  Layout.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML
import WebServer

let basicPageTitle: String = "Swift Talk - objc.io"
extension String {
    var constructTitle: String {
        return "\(self) - \(basicPageTitle)"
    }
}

struct LayoutConfig {
    var pageTitle: String
    var contents: [Node]
    var theme: String
    var metaDescription: String?
    var footerContent: [Node]
    var preFooter: [Node]
    var structuredData: StructuredData?
    var includeRecurlyJS: Bool = false
    
    init(pageTitle: String = basicPageTitle, contents: [Node], theme: String = "default", description: String? = nil, preFooter: [Node] = [], footerContent: [Node] = [], structuredData: StructuredData? = nil, includeRecurlyJS: Bool = false) {
        self.pageTitle = pageTitle
        self.contents = contents
        self.theme = theme
        self.metaDescription = description
        self.footerContent = footerContent
        self.structuredData = structuredData
        self.preFooter = preFooter
        self.includeRecurlyJS = includeRecurlyJS
    }
}

struct StructuredData {
    let twitterCard: String = "summary_large_image"
    let twitterSite: String = "@objcio"
    let title: String
    let description: String
    let url: URL?
    let image: URL?
    let type: ItemType
    
    enum ItemType {
        case video(duration: Int, releaseDate: Date)
        case website
        case other
    }
    
    init(title: String, description: String, url: URL?, image: URL?, type: ItemType = .other) {
        self.title = title
        self.description = description
        self.url = url
        self.image = image
        self.type = type
    }
    
    var ogType: String {
        switch type {
        case .other: return ""
        case .video(duration: _, releaseDate: _): return "video.episode"
        case .website: return "website"
        }
    }
    var nodes: [Node] {
        var twitter: [String:String] = ["card": twitterCard, "site": twitterSite, "title": title, "description": description]
        var og: [String:String] = ["og:type": ogType, "og:title": title, "og:description": description]
        if let u = url {
            og["og:url"] = u.absoluteString
        }
        if let i = image {
            twitter["image"] = i.absoluteString
            og["og:image"] = i.absoluteString
        }
        if case let .video(duration, date) = type {
            og["video:release_date"] = DateFormatter.iso8601.string(from: date)
            og["video:duration"] = "\(duration)"
        }
        return twitter.map { (k,v) in
            .meta(attributes: ["name": "twitter:" + k, "content": v])
            } + og.map { (k,v) in
                .meta(attributes: ["property": k, "content": v])
        }
    }
}


let navigationItems: [(LinkTarget, String)] = [
    (Route.home, "Swift Talk"),
    (URL(string: "https://www.objc.io/books")!, "Books"),
    (URL(string: "https://www.objc.io/issues")!, "Issues"),
    (URL(string: "https://www.objc.io/blog/2018/12/11/swift-talk-gift-subscription/")!, "Gifts"),
]

let rssURL = Route.rssFeed.url.absoluteString

extension LayoutConfig {
    var structured: [Node] {
        return structuredData.map { $0.nodes } ?? []
    }
    
    var layout: Node {
        let desc: String? = metaDescription ?? structuredData?.description
        let head = Node.head([
            .meta(attributes: ["charset": "utf-8"]),
            .meta(attributes: ["http-equiv": "X-UA-Compatible", "content": "IE=edge"]),
            .meta(attributes: ["name": "viewport", "content": "width=device-width, initial-scale=1, user-scalable=no"]),
            desc.map { .meta(attributes: ["name": "description", "content": $0]) } ?? .none
            ] + [
            .title(pageTitle),
            .xml(name: "link", attributes: [
                "href": rssURL,
                "rel": "alternate",
                "title": "RSS",
                "type": "application/rss+xml"
                ]),
            .xml(name: "link", attributes: [
                "href": rssURL,
                "rel": "alternate",
                "title": "Atom",
                "type": "application/atom+xml"
                ]),
            .hashedStylesheet(href: "/assets/stylesheets/application.css"),
            includeRecurlyJS ? .script(src: "https://js.recurly.com/v4/recurly.js") : .none,
            googleAnalytics,
        ] + structured)
        let logo = Node.link(to: URL(string: "https://www.objc.io")!, class: "flex-none outline-none mr++ flex", [
            .inlineSvg(class: "block logo logo--themed height-auto", path: "logo.svg"),
            .h1(class: "visuallyhidden", ["objc.io"])
        ] as [Node])
        let navigation = Node.nav(class: "flex flex-grow", [
            .ul(class: "flex flex-auto", navigationItems.map { l in
                .li(class: "flex mr+", [
                    .link(to: l.0, attributes: [
                        "class": "flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration"
                    ], [.span([.text(l.1)])])
                ])
            }) // todo: search
        ])

        let header = Node.header(class: "bgcolor-white", [
            .div(class: "height-3 flex scroller", [
                .div(class: "container-h flex-grow flex", [
                    logo,
                    navigation,
                    .withSession(userHeader)
                ])
            ])
        ])
        
        let thinkingInSwiftUIPromo = Node.raw(
            """
            <div class="theme-thinking-in-swiftui"> <section class=" pattern-shade bgcolor-theme-main color-white"> <div class="container pb+ pt+"> <a href="https://www.objc.io/books/thinking-in-swiftui" class="color-white no-decoration">→ <strong class="bold">Thinking in SwiftUI</strong>: Our new book is now available!</a> </div></section></div>
            """
        )
        var bodyChildren: [Node] = [
            header,
            thinkingInSwiftUIPromo,
            .main(
                [.none] + // TODO flash messsage should go here (there's a flash helper below)
                contents
            )
        ]
        // these are appends because of compile time
        bodyChildren.append(contentsOf: preFooter)
        bodyChildren.append(.raw(footer))
        bodyChildren.append(contentsOf: footerContent)
        let body = Node.body(attributes: ["class": "theme-" + theme], bodyChildren)
        return .html(attributes: ["lang": "en"], [head, body])
    }
    
    var layoutForCheckout: Node {
        let head = Node.head([
            .meta(attributes: ["charset": "utf-8"]),
            .meta(attributes: ["http-equiv": "X-UA-Compatible", "content": "IE=edge"]),
            .meta(attributes: ["name": "viewport", "content": "'width=device-width, initial-scale=1, user-scalable=no'"]),
            .title(pageTitle),
            .xml(name: "link", attributes: [
                "href": rssURL,
                "rel": "alternate",
                "title": "RSS",
                "type": "application/rss+xml"
            ]),
            .xml(name: "link", attributes: [
                "href": rssURL,
                "rel": "alternate",
                "title": "Atom",
                "type": "application/atom+xml"
                ]),
            .hashedStylesheet(href: "/assets/stylesheets/application.css"),
            includeRecurlyJS ? .script(src: "https://js.recurly.com/v4/recurly.js") : .none,
            googleAnalytics,
        ] + structured)
        let linkClasses: Class = "no-decoration color-inherit hover-color-black mr"
        let body = Node.body(attributes: ["class": "theme-" + theme], [
            .header(class: "site-header", [
        		.div(class: "site-header__nav flex", [
                    .div(class: "container-h flex-grow flex items-center height-3", [
                        .link(to: .home, class: "block flex-none outline-none mr++", [
                            .inlineSvg(class: "logo height-auto", path: "logo.svg"),
                            .h1(class: "visuallyhidden", ["objc.io"])
                        ] as [Node]),
                    ])
                ])
            ]),
            .main(contents),
        ] + preFooter + [
            .footer([
                .div(class: "container-h pv", [
                    .div(class: "ms-1 color-gray-60", [
                        .a(class: linkClasses, href: "mailto:mail@objc.io", ["Email"]),
                        .link(to: URL(string: "https://www.objc.io/imprint")!, class: linkClasses, ["Imprint"])
                    ])
                ])
            ])
        ] + footerContent)
        return .html(attributes: ["lang": "en"], [head, body])
    }
}

public enum FlashType {
    case notice
    case alert
}

func flash(message: String, type: FlashType) -> Node {
    let `class`: Class
    switch type {
    case .notice: `class` = "bgcolor-blue-dark"
    case .alert: `class` = "bgcolor-invalid"
    }
    return .div(class: "p-edges pv" + `class` + "color-white js-closeable pattern-shade", [
        .div(class: "wrapper flex items-center justify-between", [
            .p(class: "bold flex-auto", [.text(message)]),
            .button(class: "smallcaps reset-button color-inherit hover-color-black js-closeable-toggle", attributes: ["type": "button"], ["Close"])
        ])
    ])
}

func userHeader(_ session: Session?) -> Node {
    let subscribeButton = Node.li(class: "flex items-center ml+", [
        .link(to: .signup(.subscribe(planName: nil)), class: "button button--tight button--themed fz-nav", ["Subscribe"])
    ])
    
    func link(to route: Route, text: String) -> Node {
        return .li(class: "flex ml+", [
            .link(to: route, class: "flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration", [.text(text)])
        ])
    }
    
    let items: [Node]
    if let s = session {
        let account = link(to: .account(.profile), text: "Account")
        let logout = link(to: .account(.logout), text: "Log out")
        items = s.activeSubscription ? [account, logout] : [account, subscribeButton]
    } else {
        items = [
            .withRoute { link(to: .login(.login(continue: $0)), text: "Log in") },
            subscribeButton
        ]
    }
    return .nav(class: "flex-none self-center border-left border-1 border-color-gray-85 flex ml+", [
        .ul(class: "flex items-stretch", items)
    ])
}

let googleAnalytics = Node.raw("""
<script async src="https://www.googletagmanager.com/gtag/js?id=UA-40809116-1"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', 'UA-40809116-1');
</script>
""")
let footer = """
<footer>
<div class="container">
<div class="cols m-|stack++">
<div class="col m+|width-1/2">
<a class="inline-block mb" href="https://www.objc.io/">
<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMaxYMax meet" viewBox="0 0 528 158" width="528" height="158" class="logo logo--themed">
<g id="Logo" fill="none" fill-rule="evenodd">
<g id="objc-logo-white-fit">
<g id="arrows" fill="#FFA940">
<path id="arrow-up" d="M423 73l8-7-45.5-46L340 66l8 7 32-34v86h11V39l32 34z"></path>
<path id="arrow-down" d="M520 80l8 7-45.5 46L437 87l8-7 32 34V28h11v86l32-34z"></path>
</g>
<g id="letters" fill="#0091D9">
<path id="letter-c" d="M260.362 124c-15.38 0-25.18-7.104-31.26-16.07C224.534 101.162 222 91.855 222 79c0-12.854 2.535-22.16 7.1-28.927C235.184 41.107 244.815 34 260.196 34c10.136 0 18.417 3.383 24.334 9.136C290.272 48.72 294.327 55.696 295 65h-14.5c-1.172-5.918-3.24-10.022-6.45-13.238-3.382-3.213-8.28-5.242-13.855-5.242-6.592 0-11.156 2.367-14.87 5.583-6.76 5.753-8.622 16.408-8.622 26.898 0 10.49 1.862 21.147 8.62 26.897 3.716 3.216 8.28 5.586 14.872 5.586 5.91 0 11.15-2.2 14.528-5.753 3.044-3.213 5.072-7.105 5.777-12.73H295c-.67 9.136-4.22 16.115-9.966 21.698-6.082 5.92-14.193 9.302-24.672 9.302z"></path>
<path id="letter-j" d="M168 156.306V143.94c3.582.675 7.17.846 10.757.846 6.484 0 9.732-5.086 9.243-10.846V36h15v97.77c.002 14.91-7.34 24.23-23.732 24.23-4.438 0-7-.338-11.268-1.694zM188 0h15v15h-15V0z"></path>
<path id="letter-b" d="M132.358 124c-9.67 0-20.696-4.724-25.616-13.326L106 122H93V0h15v46c4.58-7.76 15.028-11.75 24.358-11.75 10.007 0 17.98 3.373 23.578 8.604C164.59 51.12 169 64.618 169 79.294c.002 14.173-4.238 27.162-12.38 35.43-5.6 5.735-13.743 9.276-24.262 9.276zm-1.786-78c-6.317 0-10.587 2.513-14.006 5.528-7.173 6.2-9.566 16.42-9.566 26.973 0 10.553 2.393 20.774 9.566 26.972 3.42 3.015 7.69 5.528 14.006 5.528C149.872 111 155 94.08 155 78.5c0-15.578-5.127-32.5-24.428-32.5z"></path>
<path id="letter-o" d="M63.844 114.018c-6.25 6.093-15.03 9.982-25.84 9.982s-19.592-3.89-25.843-9.982C2.876 104.884 0 92.534 0 79 0 65.47 2.875 53.117 12.16 43.983 18.41 37.892 27.192 34 38 34c10.81 0 19.59 3.89 25.84 9.982C73.13 53.116 76 65.468 76 79.002c0 13.532-2.868 25.882-12.156 35.016zm-9.85-61.953C50.42 48.528 45.315 46 38.503 46c-6.81 0-11.92 2.526-15.497 6.065C16.875 58.295 15 68.565 15 78.5c0 9.937 1.876 20.206 8.005 26.438C26.58 108.472 31.692 111 38.502 111c6.81 0 11.917-2.526 15.493-6.062C60.125 98.708 62 88.438 62 78.5c0-9.934-1.88-20.206-8.005-26.435z"></path>
</g>
</g>
</g>
</svg>

</a>        <p class="lh-125 color-gray-40">
objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development.
</p>
</div>
<div class="col width-full m+|width-1/2">
<div class="cols">
<div class="col width-1/3">
<p class="mb">
<span class="smallcaps color-gray-40">Learn</span>
</p>
<ul class="stack-">
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="/">Swift Talk</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/books">Books</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/workshops">Workshops</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/issues">Issues</a>
</li>
</ul>
</div><!-- .col -->
<div class="col width-1/3">
<p class="mb">
<span class="smallcaps color-gray-40">Follow</span>
</p>
<ul class="stack-">
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/blog">Blog</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/newsletter">Newsletter</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://twitter.com/objcio">Twitter</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.youtube.com/objcio">YouTube</a>
</li>
</ul>
</div><!-- .col -->
<div class="col width-1/3">
<p class="mb">
<span class="smallcaps color-gray-40">More</span>
</p>
<ul class="stack-">
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/about">About</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="mailto:mail@objc.io">Email</a>
</li>
<li>
<a class="no-decoration color-gray-60 hover-color-black" href="https://www.objc.io/imprint">Imprint &amp; Legal</a>
</li>
</ul>
</div><!-- .col -->
</div> <!-- .cols -->
</div>
</div>
</div>
</footer>
"""
