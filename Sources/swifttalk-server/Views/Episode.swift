//
//  Episode.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation

func index(_ items: [Episode], context: Context) -> Node {
    return LayoutConfig(context: context, contents: [
        pageHeader(.link(header: "All Episodes", backlink: .home, label: "Swift Talk")),
        .div(classes: "container pb0", [
            .div([
                .h2([.span(attributes: ["class": "bold"], [.text("\(items.count) Episodes")])], attributes: ["class": "inline-block lh-100 mb+"])
                ]),
            .ul(attributes: ["class": "cols s+|cols--2n m+|cols--3n xl+|cols--4n"], items.map { e in
                Node.li(attributes: ["class": "col mb++ width-full s+|width-1/2 m+|width-1/3 xl+|width-1/4"], [e.render(.init(synopsis: true, canWatch: (context.session.premiumAccess) || !e.subscription_only))])
            })
            ])
        ]).layout
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
        
        init(featured: Bool = false, wide: Bool = false, synopsis: Bool, watched: Bool = false, canWatch: Bool, collection: Bool = true) {
            self.featured = featured
            self.watched = watched
            self.canWatch = canWatch
            self.synopsis = synopsis
            self.wide = wide
            self.collection = collection
            if featured {
                largeIcon = true
            }
        }
    }
    
    func render(_ options: ViewOptions) -> Node {
        assert(!options.watched)
        let iconFile = options.canWatch ? "icon-play.svg" : "icon-lock.svg"
        let classes: Class = "flex flex-column width-full" + // normal
            (options.wide ? "max-width-6 m+|max-width-none m+|flex-row" : "") + // wide
            (options.featured ? "min-height-full hover-scale transition-all transition-transform" : "") // featured
        let pictureClasses: Class = options.wide ? "flex-auto mb- m+|width-1/3 m+|order-2 m+|mb0 m+|pl++" : "flex-none"
        
        let pictureLinkClasses: Class = "block ratio radius-3 overflow-hidden" +
            (options.featured ? "ratio--2/1 radius-5 no-radius-bottom" : " ratio--22/10 hover-scale transition-all transition-transform")
        
        let largeIconClasses: Class = "absolute position-stretch flex justify-center items-center color-white" + (options.canWatch ? "hover-scale-1.25x transition-all transition-transform" : "")
        
        let smallIcon: [Node] = options.largeIcon ? [] : [.inlineSvg(path: iconFile, attributes: ["class": "svg-fill-current icon-26"])]
        let largeIconSVGClass: Class = "svg-fill-current" + (options.largeIcon ? "icon-46" : "icon-26")
        let largeIcon: [Node] = options.largeIcon ? [.div(classes: largeIconClasses, [.inlineSvg(path: iconFile, classes: largeIconSVGClass)])] : []
        
        let contentClasses: Class = "flex-auto flex flex-column" +
            (options.wide ? "m+|width-2/3" : "flex-auto justify-center") +
            (!options.featured && !options.wide ? " pt-" : "") +
            (options.featured ? "pa bgcolor-pale-gray radius-5 no-radius-top" : "")
        
        let coll: [Node]
        if options.collection, let collection = primaryCollection {
            coll = [Node.link(to: Route.collection(collection.id), [.text(collection.title)], attributes: [
                "class": "inline-block no-decoration color-blue hover-underline mb--" + (options.featured ? "" : " ms-1")
                ])]
        } else { coll = [] }
        
        let synopsisClasses: Class = "lh-135 color-gray-40 mv-- text-wrapper" + (
            !options.featured && !options.wide ? " ms-1 hyphens" : "")
        
        let titleClasses: Class = "block lh-110 no-decoration bold color-black hover-underline" + (options.wide ? "ms1" : (options.featured ? "ms2" : ""))
        
        let footerClasses: Class = "color-gray-65" + (!options.wide && !options.featured ? " mt-- ms-1" : "")
        
        let synopsisNode: [Node] = options.synopsis ? [.p(classes: synopsisClasses, [.text(synopsis)])] : [] // todo widow thing
        
        // TODO sidebar!
        
        return Node.article(classes: classes, [
            Node.div(classes: pictureClasses, [
                .link(to: .episode(id), [
                    Node.div(attributes: ["class": "ratio__container bg-center bg-cover", "style": "background-image: url('\(poster_url!)')"]),
                    Node.div(attributes: ["class": "absolute position-stretch opacity-60 blend-darken gradient-episode-black"]),
                    Node.div(classes: "absolute position-stretch flex flex-column", [
                        Node.div(classes: "mt-auto width-full flex items-center lh-100 ms-1 pa- color-white",
                                 smallIcon + [Node.span(attributes: ["class": "ml-auto bold text-shadow-20"], [.text("\(media_duration!.minutes)")])] // todo format text
                        )
                        ])
                    ] + largeIcon, classes: pictureLinkClasses)
                ]),
            Node.div(classes: contentClasses, [
                Node.header(coll + ([
                    Node.h3([Node.link(to: .episode(id), [Node.text(title + (released ? "" : " (unreleased)"))], classes: titleClasses)])
                    ] as [Node])),
                ] + synopsisNode + [
                    .p(classes: footerClasses, [
                        Node.text("Episode \(number)"),
                        Node.span(attributes: ["class": "ph---"], [.raw("&middot;")]),
                        Node.text("\(releasedAt?.pretty ?? "Not yet released")") // todo
                        ])
                ]),
            
            ])
    }
    
}

extension Node {
    static func externalLink(to: URL, classes: Class?, children: [Node]) -> Node {
        return Node.link(to: .external(to), children, classes: classes, attributes: ["target": "_blank", "rel": "external"])
    }
}


extension Episode {
    enum DownloadStatus {
        case notSubscribed
        case reDownload
        case canDownload(creditsLeft: Int)
        case noCredits
        
        var allowed: Bool {
            if case .reDownload = self { return true }
            if case .canDownload = self { return true }
            return false
        }
        
        var text: String {
            switch self {
            case .notSubscribed:
                return "Become a subscriber to download episode videos."
            case .reDownload:
                return "Re-downloading episodes doesn’t use any download credits."
            case let .canDownload(creditsLeft):
                return "You have \(creditsLeft) download credits left"
            case .noCredits:
                return "No download credits left. You’ll get new credits at the next billing cycle."
            }
        }
    }

    fileprivate func player(canWatch: Bool, playPosition: Int?) -> Node {
        let startTime = playPosition.map { "#t=\($0)s" } ?? ""
        let vimeoId = canWatch ? vimeo_id : (preview_vimeo_id ?? 0)
        return .div(classes: "ratio ratio--16/9", [
            .div(classes: "ratio__container", [
                .figure(attributes: ["class":"stretch relative"], [
                    Node.iframe(URL(string: "https://player.vimeo.com/video/\(vimeoId)\(startTime)")!, attributes: [
                        "width": "100%",
                        "height": "100%",
                        "webkitallowfullscreen": "",
                        "mozallowfullscreen": "",
                        "allowfullscreen": ""
                    ])
                ] + (canWatch ? [] : [Node.raw(previewBadge)]))
            ])
        ])
    }
    
    fileprivate func toc(canWatch: Bool) -> Node {
        let wrapperClasses = "flex color-inherit pv"
        
        func item(_ entry: (TimeInterval, title: String)) -> Node {
            guard canWatch else {
                return Node.span(attributes: ["class": wrapperClasses], [.text(entry.title)])
            }
            
            return Node.a(attributes: ["class": wrapperClasses + " items-baseline no-decoration hover-cascade js-episode-seek"], [
                Node.span(attributes: ["class": "hover-cascade__underline"], [.text(entry.title)]),
                Node.span(attributes: ["class": "ml-auto color-orange pl-"], [.text(entry.0.timeString)]),
                ], href: "?t=\(Int(entry.0))")
        }
        
        let items = [(6, title: "Introduction")] + tableOfContents
        
        return .div(classes: "l+|absolute l+|position-stretch stretch width-full flex flex-column", [
            Node.h3([
                .span(attributes: ["class": "smallcaps"], [.text(canWatch ? "In this episode" : "In the full episode")]),
                .span(attributes: ["class": "ml-auto ms-1 bold"], [.text(media_duration!.timeString)])
                ], attributes: ["class": "color-blue border-top border-2 pt mb+ flex-none flex items-baseline"]),
            Node.div(classes: "flex-auto overflow-auto border-color-lighten-10 border-1 border-top", [
                Node.ol(attributes: ["class": "lh-125 ms-1 color-white"], items.map { entry in
                    Node.li(attributes: ["class": "border-bottom border-1 border-color-lighten-10"], [
                        item(entry)
                        ])
                })
                ])
            ])
    }
    
    func show(watched: Bool = false, downloadStatus: DownloadStatus, context: Context) -> Node {
        let canWatch = !subscription_only || context.session.premiumAccess
        let guests_: [Node] = [] // todo
        // todo: subscribe banner
        
        let scroller =  // scroller
            Node.aside(attributes: ["class": "bgcolor-pale-gray pt++ js-scroller"], [
                Node.header(attributes: ["class": "container-h flex items-center justify-between"], [
                    Node.div([
                        Node.h3([.text("Recent Episodes")], attributes: ["class": "inline-block bold color-black"]),
                        Node.link(to: .episodes, [.text("See All")], attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"])
                        ]),
                    Node.div(classes: "js-scroller-buttons flex items-center", [
                        Node.button(attributes: ["class": "scroller-button no-js-hide js-scroller-button-left ml-", "label": "Scroll left"], [
                            Node.inlineSvg(path: "icon-arrow-16-left.svg", preserveAspectRatio: "xMinYMid meet", attributes: ["class": "icon-16 color-white svg-fill-current block"])
                            ]),
                        Node.button(attributes: ["class": "scroller-button no-js-hide js-scroller-button-right ml-", "label": "Scroll right"], [
                            Node.inlineSvg(path: "icon-arrow-16.svg", preserveAspectRatio: "xMinYMid meet", attributes: ["class": "icon-16 color-white svg-fill-current block"])
                            ])
                        ])
                    ]),
                Node.div(classes: "flex scroller js-scroller-container p-edges pt pb++", [
                    Node.div(classes: "scroller__offset flex-none")
                    ] + Episode.scoped(for: context.session?.user.data).filter { $0 != self }.prefix(8).map { e in
                        Node.div(classes: "flex-110 pr+ min-width-5", [e.render(.init(synopsis: false, canWatch: canWatch))]) // todo watched
                    })
                ])
        
        func smallBlueH3(_ text: Node) -> Node {
            return Node.h3(classes: "color-blue mb", [Node.span(classes: "smallcaps", [text])])
        }
        
        let linkAttrs: [String:String] = ["target": "_blank", "rel": "external"]

        // nil link displays a "not allowed" span
        func smallH4(_ text: Node, link: Route?) -> Node {
            return Node.h4(classes: "mb---", [
                link.map { l in
                    Node.link(to: l, [text], classes: "bold color-black hover-underline no-decoration", attributes: linkAttrs)
                } ??
                Node.span(classes: "bold color-gray-40 cursor-not-allowed", [text])
                ])
        }
        
        let episodeResource: [[Node]] = self.resources.values.map { res in
            [
                Node.div(classes: "flex-none mr-", [
                    Node.a(classes: "block bgcolor-orange radius-5 hover-bgcolor-blue", attributes: linkAttrs, [
                        Node.inlineSvg(path: "icon-resource-code.svg", classes: "block icon-40")
                        ], href: res.url.absoluteString)
                ]),
                Node.div(classes: "ms-1 lh-125", [
                    smallH4(.text(res.title), link: .external(res.url)),
                    Node.p(classes: "color-gray-50", [.text(res.subtitle)])
                ])
            ]
        }
        let downloadImage = Node.inlineSvg(path: "icon-resource-download.svg", classes: "block icon-40")
        let download: [[Node]] = [
            [Node.div(classes: "flex-none mr-", [
                downloadStatus.allowed ? Node.link(to: Route.download(number), [downloadImage], classes: "block bgcolor-orange radius-5 hover-bgcolor-blue")
                    : Node.span(classes: "block bgcolor-orange radius-5 cursor-not-allowed", [downloadImage])
                
            ]),
            Node.div(classes: "ms-1 lh-125", [
                smallH4(.text("Episode Video"), link: downloadStatus.allowed ? Route.download(number) : nil),
                .p(classes: "color-gray-50", [.text(downloadStatus.text)])
            ]),
            ]
        ] // todo
        let resourceItems: [[Node]] = episodeResource + download
        let resources: [Node] = canWatch ? [
            Node.section(classes: "pb++", [
                smallBlueH3("Resources"),
            Node.ul(classes: "stack", resourceItems.map { Node.li(classes: "flex", $0)})
            ])
        ] : []
        
        let inCollection: [Node] = primaryCollection.map { coll in
            [Node.section(classes: "pb++", [
                smallBlueH3("In Collection")
                ] +
                coll.render(.init(episodes: true), context: context)
                + [Node.p(classes: "ms-1 mt text-right", [
                    Node.link(to: .collections, [
                        Node.span(classes: "hover-cascade__border-bottom", ["See All Collections"]),
                        Node.span(classes: "bold", [Node.raw("&rarr;")])
                    ], classes: "no-decoration color-blue hover-cascade")])
                ])
            ]
        } ?? []
        let detailItems: [(String,String, URL?)] = [
            ("Released", DateFormatter.fullPretty.string(from: releasedAt ?? Date()), nil)
            ] + theCollaborators.sorted(by: { $0.role < $1.role }).map { coll in
                (coll.role.name, coll.name, .some(coll.url))
        }
        let details = canWatch ? [
            Node.div(classes: "pb++", [
                smallBlueH3("Episode Details"),
                Node.ul(classes: "ms-1 stack", detailItems.map { key, value, url in
                    Node.li([
                        Node.dl(classes: "flex justify-between", [
                            Node.dt(classes: "color-gray-60", [.text(key)]),
                            Node.dd(classes: "color-gray-15 text-right", [url.map { u in
                                Node.externalLink(to: u, classes: "color-gray-15 hover-underline no-decoration", children: [.text(value)])
                            } ?? .text(value)])
                        ])
                    ])
                })
            ])
        ] : []
        let sidebar: Node = Node.aside(classes: "p-col max-width-7 center stack l+|width-1/3 xl+|width-3/10 l+|flex-auto", resources + inCollection + details)
        let main: Node = Node.div(classes: "js-episode", [
            .div(classes: "bgcolor-night-blue pattern-shade-darker", [
                .div(classes: "container l+|pb0 l+|n-mb++", [
                    .header(attributes: ["class": "mb++ pb"], [
                        .p(attributes: ["class": "color-orange ms1"], [
                            .link(to: .home, [.text("Swift Talk")], attributes: ["class": "color-inherit no-decoration bold hover-border-bottom"]),
                            .text("#" + number.padded)
                            ]),
                        .h2([.text(fullTitle + (released ? "" : " (unreleased)"))], attributes: ["class": "ms5 color-white bold mt-- lh-110"])
                        ] + guests_ ),
                    .div(classes: "l+|flex", [
                        .div(classes: "flex-110 order-2", [
                            player(canWatch: canWatch, playPosition: nil)
                        ]),
                        .div(classes: "min-width-5 relative order-1 mt++ l+|mt0 l+|mr++ l+|mb++", [
                            toc(canWatch: canWatch)
                            ])
                        ])
                    ])
                ]),
            .div(classes: "bgcolor-white l+|pt++", [
                .div(classes: "container", canWatch ? [
                    .raw(subscriptionPitch),
                    .div(classes: "l+|flex l-|stack+++ m-cols", [
                        .div(classes: "p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 flex flex-column", [
                            Node.div(classes: "text-wrapper", [
                                Node.div(classes: "lh-140 color-blue-darkest ms1 bold mb+", [
                                    .markdown(synopsis),
                                    // todo episode.updates
                                    ])
                                ]),
                            .div(classes: "flex-auto relative min-height-5", [
                                .div(attributes: ["class": "js-transcript js-expandable z-0", "data-expandable-collapsed": "absolute position-stretch position-nw overflow-hidden", "id": "transcript"], [
                                    Node.raw(expandTranscript),
                                    Node.div(classes: "c-text c-text--fit-code z-0 js-has-codeblocks", [
                                        .raw(transcript?.html ?? "No transcript yet.")
                                        ])
                                    ])
                                ])
                            ]),
                        	sidebar
                        ])
                    ] : [
                        .div(classes: "bgcolor-pale-blue border border-1 border-color-subtle-blue radius-5 ph pv++ flex flex-column justify-center items-center text-center min-height-6", [
                            Node.inlineSvg(path: "icon-blocked.svg"),
                            .div(classes: "mv", [
                                .h3([.text("This episode is exclusive to Subscribers")], attributes: ["class":"ms1 bold color-blue-darkest"]),
                                .p(attributes: ["class": "mt- lh-135 color-blue-darkest opacity-60 max-width-8"], [.text("Become a subscriber to watch future and all \(Episode.subscriberOnly) current subscriber-only episodes, plus enjoy access to episode video downloads and \(teamDiscount)% discount for your team members.")])
                                
                                ]),
                            Node.link(to: .subscribe, [Node.text("Become a subscriber")], attributes: ["class": "button button--themed"])
                            ])
                    ])
                ])
            ])
        
        let data = StructuredData(title: title, description: synopsis, url: absoluteURL(.episode(id)), image: poster_url, type: .video(duration: media_duration.map(Int.init), releaseDate: releasedAt))
        return LayoutConfig(context: context, contents: [main, scroller] + (context.session.premiumAccess ? [] : [subscribeBanner()]), footerContent: [Node.raw(transcriptLinks)], structuredData: data).layout
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
<a href="\(Route.subscribe.path)" class="color-blue no-decoration hover-cascade">
<span class="hover-cascade__border-bottom">Become a Subscriber</span> <span class="bold">&rarr;</span>
</a>
</p>
</div>
</div>

"""

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
    static var subscriberOnly: Int {
        return all.lazy.filter { $0.subscription_only }.count
    }
}

func subscribeBanner() -> Node {
    return Node.aside(attributes: ["class": "bgcolor-blue"], [
        Node.div(classes: "container", [
            Node.div(classes: "cols relative s-|stack+", [
                Node.raw("""
  <div class="col s+|width-1/2 relative">
    <p class="smallcaps color-orange mb">Unlock Full Access</p>
    <h2 class="color-white bold ms3">Subscribe to Swift Talk</h2>
  </div>
"""),
                Node.div(classes: "col s+|width-1/2", [
                    Node.ul(attributes: ["class": "stack+ lh-110"], benefits.map { b in
                        Node.li([
                            Node.div(classes: "flag", [
                                Node.div(classes: "flag__image pr color-orange", [
                                    Node.inlineSvg(path: b.icon, attributes: ["class": "svg-fill-current"])
                                    ]),
                                Node.div(classes: "flag__body", [
                                    Node.h3([Node.text(b.name)], attributes: ["class": "bold color-white mb---"]),
                                    Node.p(attributes: ["class": "color-blue-darkest lh-125"], [Node.text(b.description)])
                                    ])
                                ])
                            ])
                    })
                    ]),
                Node.div(classes: "s+|absolute s+|position-sw col s+|width-1/2", [
                    Node.link(to: .subscribe, [.raw("Pricing &amp; Sign Up")], attributes: ["class": "c-button"])
                    ])
                ])
            ])
        ])
}

