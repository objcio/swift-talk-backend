//
//  Views.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

struct LayoutConfig {
    var pageTitle: String
    var contents: [Node]
    var theme: String
    var footerContent: [Node]
    var structuredData: StructuredData?
    
    init(pageTitle: String = "objc.io", contents: [Node], theme: String = "default", footerContent: [Node] = [], structuredData: StructuredData? = nil) {
        self.pageTitle = pageTitle
        self.contents = contents
        self.theme = theme
        self.footerContent = footerContent
        self.structuredData = structuredData
    }
}

let navigationItems: [(MyRoute, String)] = [
    (.home, "Swift Talk"), // todo
    (.books, "Books"),
    (.issues, "Issues")
]

let test = """
<nav class="flex-none self-center border-left border-1 border-color-gray-85 flex ml+">
<ul class="flex items-stretch">
<li class="flex ml+">
<a class="flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration" href="/users/auth/github">Log in</a>
</li>

<li class="flex items-center ml+">
<a class="button button--tight button--themed fz-nav" href="/subscribe">Subscribe</a>
</li>
</ul>
</nav>
"""

enum HeaderContent {
    case node(Node)
    case other(header: String, blurb: String)
    
    var asNode: [Node] {
        switch self {
        case let .node(n): return [n]
        case let .other(header: text, blurb: blurb): return [
        	.h1(text, attributes: ["class": "color-white bold ms4"]), // todo add pb class where blurb = nil
            .div(class: "mt--", [
            .p(attributes: ["class": "ms2 color-darken-50 lh-110 mw7"], [.text(blurb)])
            ])
        ]
        }
    }
}

func pageHeader(_ content: HeaderContent) -> Node {
    return .header(attributes: ["class": "bgcolor-blue pattern-shade"], [
        .div(class: "container", content.asNode)
    ])
}

extension TimeInterval {
    private var hm: (Int, Int, Int) {
        let h = floor(self/(60*60))
        let m = floor(self.truncatingRemainder(dividingBy: 60*60)/60)
        let s = self.truncatingRemainder(dividingBy: 60).rounded()
        return (Int(h), Int(m), Int(s))
    }
    
    var minutes: String {
        let m = Int((self/60).rounded())
        return "\(m) min"
    }
    
    var hoursAndMinutes: String {
        let (hours, minutes, _) = hm
        if hours > 0 {
            return "\(Int(hours))h\(minutes.padded)min"
        } else { return "\(minutes)min" }
    }
    
    var timeString: String {
        let (hours, minutes, seconds) = hm
        if hours == 0 {
        	return "\(minutes.padded):\(seconds.padded)"
        } else {
            return "\(hours):\(minutes.padded):\(seconds.padded)"
        }
    }
}

extension DateFormatter {
    static let withYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM dd yyyy"
        return f
    }()
    
    static let withoutYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM dd"
        return f
    }()
}

extension Date {
    fileprivate var pretty: String {
        let cal = NSCalendar.current
        if cal.component(.year, from: Date()) == cal.component(.year, from: self) {
            return DateFormatter.withoutYear.string(from: self)
        } else {
        	return DateFormatter.withYear.string(from: self)
        }
    }
}

extension Episode {
    struct ViewOptions {
        var featured: Bool = false
        var largeIcon: Bool = false
        var watched: Bool = false
        var canWatch: Bool = false
        var wide: Bool = false
        var collection: Bool = true
        var synopsis: Bool = false
        
        init(featured: Bool = false, watched: Bool = false, canWatch: Bool = false) {
            self.featured = featured
            self.watched = watched
            self.canWatch = canWatch
            if featured {
                synopsis = true
                largeIcon = true
            }
        }
    }
    func render(_ options: ViewOptions) -> Node {
        assert(!options.watched)
        assert(!options.canWatch)
        let iconFile = "icon-lock.svg"
        let classes = "flex flex-column width-full" + // normal
//            " max-width-6 m+|max-width-none m+|flex-row" + // wide
            (options.featured ? " min-height-full hover-scale transition-all transition-transform" : "") // featured
        let pictureClasses = "flex-none"
        
        let pictureLinkClasses = "block ratio radius-3 overflow-hidden" +
            (options.featured ? " ratio--2/1 radius-5 no-radius-bottom" : " ratio--22/10 hover-scale transition-all transition-transform")
        
        let largeIconClasses = "absolute position-stretch flex justify-center items-center color-white" + (options.canWatch ? " hover-scale-1.25x transition-all transition-transform" : "")

        let smallIcon: [Node] = options.largeIcon ? [] : [.inlineSvg(path: iconFile, attributes: ["class": "svg-fill-current icon-26"])]
        let largeIconSVGClass = "svg-fill-current " + (options.largeIcon ? "icon-46" : "icon-26")
        let largeIcon: [Node] = options.largeIcon ? [.div(class: largeIconClasses, [.inlineSvg(path: iconFile, attributes: ["class": largeIconSVGClass])])] : []
        
        let contentClasses = "flex-auto flex flex-column" +
          (options.wide ? " m+|width-2/3" : " flex-auto justify-center") +
          (!options.featured && !options.wide ? " pt-" : "") +
          (options.featured ? " pa bgcolor-pale-gray radius-5 no-radius-top" : "")
        
        let coll: [Node]
        if options.collection, let id = collection, let collection = Collection.all.first(where: { $0.id == id }) {
            coll = [Node.link(to: MyRoute.collection(collection.slug), collection.title, attributes: [
                "class": "inline-block no-decoration color-blue hover-underline mb--" + (options.featured ? "" : " ms-1")
            ])]
        } else { coll = [] }
        
        let synopsisClasses = "lh-135 color-gray-40 mv-- text-wrapper" + (
        !options.featured && !options.wide ? " ms-1 hyphens" : "")
        
        let titleClasses = "block lh-110 no-decoration bold color-black hover-underline" + (options.wide ? " ms1" : (options.featured ? " ms2" : ""))
        
        let footerClasses = "color-gray-65" + (!options.wide && !options.featured ? " mt-- ms-1" : "")
        
        let synopsisNode: [Node] = options.synopsis ? [.p(attributes: ["class": synopsisClasses], [.text(synopsis)])] : [] // todo widow thing
        
        return .article(attributes: ["class": classes], [
            Node.div(class: pictureClasses, [
                .link(to: .episode(slug), [
        			Node.div(attributes: ["class": "ratio__container bg-center bg-cover", "style": "background-image: url('\(poster_url!)')"]),
        			Node.div(attributes: ["class": "absolute position-stretch opacity-60 blend-darken gradient-episode-black"]),
                    Node.div(class: "absolute position-stretch flex flex-column", [
                        Node.div(class: "mt-auto width-full flex items-center lh-100 ms-1 pa- color-white",
                            smallIcon + [Node.span(attributes: ["class": "ml-auto bold text-shadow-20"], "\(media_duration!.minutes)")] // todo format text
                        )
                    ])
        		] + largeIcon, attributes: ["class": pictureLinkClasses])
            ]),
            Node.div(class: contentClasses, [
                .header(coll + [
                    Node.h3(Node.link(to: .episode(slug), title, attributes: ["class": titleClasses]))
                ]),
                ] + synopsisNode + [
                .p(attributes: ["class": footerClasses
                    ], [
                        .text("Episode \(number)"),
                        Node.span(attributes: ["class": "ph---"], "&middot;"),
                        .text("\(releasedAt?.pretty ?? "Not yet released")") // todo
                    ])
            ]),
//            Node.raw(episodeDetail)

        ])
    }

}


let previewBadge = """
<div class="js-video-badge bgcolor-orange color-white bold absolute position-nw width-4">
  <div class="ratio ratio--1/1">
    <div class="ratio__container flex flex-column justify-end items-center">
      <p class="smallcaps mb">Preview</p>
    </div>
  </div>
</div>
"""

extension Episode {
    struct Media {
        var url: URL
        var type: String
        var sample: Bool
    }
    fileprivate func player(media: Media, canWatch: Bool, playPosition: Int?) -> Node {
        var attrs = [
            "class":       "stretch js-video video-js vjs-big-play-centered vjs-default-skin",
            "id":          "episode-video",
            "controls":    "true",
            "preload":     "auto",
            "playsinline": "true"
        ]
        if media.sample {
            attrs["data-sample"] = "true"
        } else if let startTime = playPosition {
            attrs["start_time"] = "\(startTime)"
        }
        return .div(class: "ratio ratio--16/9", [
            .div(class: "ratio__container", [
                .figure(attributes: ["class":"stretch relative"], [
                    Node.video(attributes: attrs, media.url, sourceType: media.type)
        		] + (canWatch ? [] : [Node.raw(previewBadge)]))
            ])
        ])
    }
    
    fileprivate func toc(canWatch: Bool) -> Node {
        let wrapperClasses = "flex color-inherit pv"
        
        func item(_ entry: (TimeInterval, title: String)) -> Node {
            guard canWatch else {
                return Node.span(attributes: ["class": wrapperClasses], entry.title)
            }
            
            return Node.a(attributes: ["class": wrapperClasses + " items-baseline no-decoration hover-cascade js-episode-seek"], [
                Node.span(attributes: ["class": "hover-cascade__underline"], entry.title),
                Node.span(attributes: ["class": "ml-auto color-orange pl-"], entry.0.timeString),
            ], href: "?t=\(Int(entry.0))")
        }
        
        let items = [(6, title: "Introduction")] + tableOfContents

        return .div(class: "l+|absolute l+|position-stretch stretch width-full flex flex-column", [
            Node.h3([
                .span(attributes: ["class": "smallcaps"], canWatch ? "In this episode" : "In the full episode"),
                .span(attributes: ["class": "ml-auto ms-1 bold"], media_duration!.timeString)
            ], attributes: ["class": "color-blue border-top border-2 pt mb+ flex-none flex items-baseline"]),
            Node.div(class: "flex-auto overflow-auto border-color-lighten-10 border-1 border-top", [
                Node.ol(attributes: ["class": "lh-125 ms-1 color-white"], items.map { entry in
                    Node.li(attributes: ["class": "border-bottom border-1 border-color-lighten-10"], [
                        item(entry)
                    ])
                })
            ])
        ])
    }
    
    func show(watched: Bool = false, canWatch: Bool = true, premiumUser: Bool = false) -> Node {
        // todo meta-data
        assert(guests == nil || guests?.count == 0) // todo
        let guests_: [Node] = []
        let main: Node = .div(class: "js-episode", [
            .div(class: "bgcolor-night-blue pattern-shade-darker", [
                .div(class: "container l+|pb0 l+|n-mb++", [
                    .header(attributes: ["class": "mb++ pb"], [
                        .p(attributes: ["class": "color-orange ms1"], [
                            .link(to: .home, "Swift Talk", attributes: ["class": "color-inherit no-decoration bold hover-border-bottom"]),
                            .text("#" + number.padded)
                        ]),
                        .h2(fullTitle, attributes: ["class": "ms5 color-white bold mt-- lh-110"])
                    ] + guests_ ),
                    .div(class: "l+|flex", [
                        .div(class: "flex-110 order-2", [
                            player(media: Media(url: media_url!, type: "application/x-mpegURL", sample: true), canWatch: canWatch, playPosition: nil) // todo
                        ]),
                        .div(class: "min-width-5 relative order-1 mt++ l+|mt0 l+|mr++ l+|mb++", [
                            toc(canWatch: canWatch)
                        ])
                    ])
                ])
            ]),
            .div(class: "bgcolor-white l+|pt++", [
                .div(class: "container", canWatch ? [
                    .raw(subscriptionPitch),
                    .div(class: "l+|flex l-|stack+++ m-cols", [
                    .div(class: "p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 flex flex-column", [
                        Node.div(class: "text-wrapper", [
                            Node.div(class: "lh-140 color-blue-darkest ms1 bold mb+", [
                                .markdown(synopsis),
                                // todo episode.updates
                            ])
                        ]),
                        .div(class: "flex-auto relative min-height-5", [
                            .div(attributes: ["class": "js-transcript js-expandable z-0", "data-expandable-collapsed": "absolute position-stretch position-nw overflow-hidden", "id": "transcript"], [
                                Node.raw(expandTranscript),
                                Node.div(class: "c-text c-text--fit-code z-0 js-has-codeblocks", [
                                    .raw(transcript?.html ?? "No transcript yet.")
                                    ])
                                ])
                            ])
                        ])
                    ])
            	] : [
                    .div(class: "bgcolor-pale-blue border border-1 border-color-subtle-blue radius-5 ph pv++ flex flex-column justify-center items-center text-center min-height-6", [
                        Node.inlineSvg(path: "icon-blocked.svg"),
                        .div(class: "mv", [
                            .h3("This episode is exclusive to Subscribers", attributes: ["class":"ms1 bold color-blue-darkest"]),
        					.p(attributes: ["class": "mt- lh-135 color-blue-darkest opacity-60 max-width-8"], "Become a subscriber to watch future and all \(Episode.subscriberOnly) current subscriber-only episodes, plus access to episode video downloads, and \(teamDiscount)% discount for your team members.")
                            
                        ]),
                        Node.link(to: .subscribe, "Become a subscriber", attributes: ["class": "button button--themed"])
                    ])
                ])
            ])
        ])
        
        let data = StructuredData(title: title, description: synopsis, url: absoluteURL(.episode(slug)), image: poster_url, type: .video(duration: media_duration.map(Int.init), releaseDate: releasedAt))
        return LayoutConfig(contents: [main], footerContent: [Node.raw(transcriptLinks)], structuredData: data).layout
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let dateFormatter = DateFormatter()
        let enUSPosixLocale = Locale(identifier: "en_US_POSIX")
        dateFormatter.locale = enUSPosixLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        return dateFormatter
    }()
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
        case video(duration: Int?, releaseDate: Date?)
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
        if case let .video(duration?, date?) = type {
            og["video:release_date"] = DateFormatter.iso8601.string(from: date)
            og["video:duration"] = "\(duration)"
        }
        return twitter.map { (k,v) in
            Node.meta(attributes: ["name": "twitter:" + k, "content": v])
        } + og.map { (k,v) in
            Node.meta(attributes: ["property": k, "content": v])
        }
    }
}


let transcriptLinks = """
<script>
  $(function () {
    $('.js-transcript').find("a[href^='#']").each(function () {
      if (/^\\d+$/.test(this.hash.slice(1)) && /^\\d{1,2}(:\\d{2}){1,2}$/.test(this.innerHTML)) {
        var time = parseInt(this.hash.slice(1));
        $(this)
          .data('time', time)
          .attr('href', '?t='+time)
          .addClass('js-episode-seek js-transcript-cue');
      }
    });

    // Auto-expand transcript if #transcript hash is passed
    if (window.location.hash.match(/^#?transcript$/)) {
      $('#transcript').find('.js-expandable-trigger').trigger('click');
    }

  });
</script>
"""

let expandTranscript = """
  <div class="no-js-hide absolute height-4 gradient-fade-to-white position-stretch-h position-s ph z-1" data-expandable-expanded="hide">
    <div class="absolute position-s width-full text-wrapper text-center">
      <button type="button" class="js-expandable-trigger smallcaps button radius-full ph+++">Continue reading…</button>
    </div>
  </div>
"""

let subscriptionPitch: String = """
    <div class="bgcolor-pale-blue border border-1 border-color-subtle-blue color-blue-darkest pa+ radius-5 mb++">
    <div class="max-width-8 center text-center">
    <h3 class="mb-- bold lh-125">This episode is freely available thanks to the support of our subscribers</h3>
    <p class="lh-135">
    <span class="opacity-60">Subscribers get exclusive access to new and all previous subscriber-only episodes, video downloads, and 30% discount for team members.</span>
<a href="\(routes.print(.subscribe)!.prettyPath)" class="color-blue no-decoration hover-cascade">
    <span class="hover-cascade__border-bottom">Become a Subscriber</span> <span class="bold">&rarr;</span>
</a>
    </p>
    </div>
    </div>

"""

extension Episode {
    static var subscriberOnly: Int {
        return all.lazy.filter { $0.subscription_only }.count
    }
}

extension Int {
    func pluralize(_ text: String) -> String {
        assert(text == "Episode") // todo
        if self == 1 {
            return "1 " + text
        } else {
            return "\(self) \(text)s"
        }
    }
}

extension Collection {
    struct ViewOptions {
        var episodes: Bool = false
        var whiteBackground: Bool = false
    }
    func render(_ options: ViewOptions = ViewOptions()) -> [Node] {
        let figureStyle = "background-color: " + (options.whiteBackground ? "#FCFDFC" : "#F2F4F2")
        return [
            Node.article([
                .link(to: .collection(slug), [
                    .figure(attributes: ["class": "mb-", "style": figureStyle], [
                        .img(src: artwork, attributes: ["class": "block width-full height-auto"])
                    ]),
                ]),
                .div(class: "flex items-center pt--", [
                    Node.h3(Node.link(to: .collection(slug), title, attributes: ["class": "inline-block lh-110 no-decoration bold color-black hover-under"]))
                ] + (new ? [
                    .span(attributes: ["class": "flex-none label smallcaps color-white bgcolor-blue nowrap ml-"], "New")
                ] : [])),
                .p(attributes: ["class": "ms-1 color-gray-55 lh-125 mt--"], [
                    .text(episodes_count.pluralize("Episode")),
                    .span(attributes: ["class": "ph---"], Node.raw("&middot;")),
                    .text(total_duration.hoursAndMinutes)
                ] as [Node])
            ])
        ]
    }
}

extension LayoutConfig {
    var layout: Node {
        let structured: [Node] = structuredData.map { $0.nodes } ?? []
        return .html(attributes: ["lang": "en"], [
            .head([
                .meta(attributes: ["charset": "utf-8"]),
                .meta(attributes: ["http-equiv": "X-UA-Compatible", "content": "IE=edge"]),
                .meta(attributes: ["name": "viewport", "content": "'width=device-width, initial-scale=1, user-scalable=no'"]),
                .title(pageTitle),
                // todo rss+atom links
                .stylesheet(href: "/assets/stylesheets/application.css"),
                // todo google analytics
                ] + structured),
            .body(attributes: ["class": "theme-" + theme], [ // todo theming classes?
                .header(attributes: ["class": "bgcolor-white"], [
                    .div(class: "height-3 flex scroller js-scroller js-scroller-container", [
                        .div(class: "container-h flex-grow flex", [
                            .link(to: .home, [
        						.inlineSvg(path: "logo.svg", attributes: ["class": "block logo logo--themed height-auto"]), // todo scaling parameter?
        						.h1("objc.io", attributes: ["class":"visuallyhidden"]) // todo class
        					] as [Node]
                            , attributes: ["class": "flex-none outline-none mr++ flex"]),
        					.nav(attributes: ["class": "flex flex-grow"], [
                                .ul(attributes: ["class": "flex flex-auto"], navigationItems.map { l in
                                    .li(attributes: ["class": "flex mr+"], [
                                        .link(to: l.0, Node.span(l.1), attributes: [
                                            "class": "flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration"
                                        ])
                                    ])
                                }) // todo: search
                            ]),
                            .raw(test)
                        ])
                    ])
                ]),
                .main(contents.elements), // todo sidenav
                .raw(footer),
            ] + footerContent)
        ])
    }

}

extension Int {
    var padded: String {
        return self < 10 ? "0" + "\(self)" : "\(self)"
    }
}

extension Collection {
    var slug: Slug<Collection> {
        return Slug(rawValue: title.asSlug)
    }
}

extension String {
    var asSlug: String {
        let allowed = CharacterSet.alphanumerics
        return components(separatedBy: allowed.inverted).filter { !$0.isEmpty }.joined(separator: "-").lowercased() // todo check logic
    }
}

func renderHome() -> [Node] {
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming."))
    let recentEpisodes: Node = .section(attributes: ["class": "container"], [
        Node.header(attributes: ["class": "mb+"], [
            .h2("Recent Episodes", attributes: ["class": "inline-block bold color-black"]),
            .link(to: .episodes, "See All", attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-under"])
            ]),
        .div(class: "m-cols flex flex-wrap", [
            .div(class: "mb++ p-col width-full l+|width-1/2", [
                Episode.all.first!.render(Episode.ViewOptions(featured: true))
                ]),
            .div(class: "p-col width-full l+|width-1/2", [
                .div(class: "s+|cols s+|cols--2n",
                     Episode.all[1..<5].map { ep in
                        .div(class: "mb++ s+|col s+|width-1/2", [ep.render(Episode.ViewOptions())])
                    }
                )
                ])
            ])
        ])
    let collections: Node = .section(attributes: ["class": "container"], [
        .header(attributes: ["class": "mb+"], [
            .h2("Collections", attributes: ["class": "inline-block bold lh-100 mb---"]),
            .link(to: .collections, "Show Contents", attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"]),
            .p(attributes: ["class": "lh-125 color-gray-60"], [
                .text("Browse all Swift Talk episodes by topic.")
                ])
            ]),
        .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], Collection.all.map { coll in
            Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render())
        })
    ])
    return [header, recentEpisodes, collections]
}

extension Episode {
    var slug: Slug<Episode> {
        return Slug(rawValue: "S\(season.padded)E\(number.padded)-\(title.asSlug)")
    }
}

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
                  <a class="no-decoration color-gray-60 hover-color-black" href="/imprint">Imprint &amp; Legal</a>
                  </li>
              </ul>
            </div><!-- .col -->
        </div> <!-- .cols -->
      </div>
    </div>
  </div>
</footer>
"""
