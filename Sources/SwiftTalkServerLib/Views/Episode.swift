//
//  Episode.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML
import WebServer


func index(_ episodes: [EpisodeWithProgress]) -> Node {
    return LayoutConfig( contents: [
        pageHeader(.link(header: "All Episodes", backlink: .home, label: "Swift Talk")),
        .div(classes: "container pb0", [
            .div([
                .h2(attributes: ["class": "inline-block lh-100 mb+"], [
                    .span(classes: "bold", [
                        .text("\(episodes.count) Episodes")
                    ])
                ])
            ]),
            .ul(attributes: ["class": "cols s+|cols--2n m+|cols--3n xl+|cols--4n"], episodes.map { e in
                Node.li(attributes: ["class": "col mb++ width-full s+|width-1/2 m+|width-1/3 xl+|width-1/4"], [
                    Node.withContext { context in e.episode.render(.init(synopsis: true, watched: e.watched, canWatch: e.episode.canWatch(session: context.session))) }
                ])
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
        let iconFile = options.canWatch ? (options.watched ? "icon-watched.svg" : "icon-play.svg") : "icon-lock.svg"
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
            coll = [Node.link(to: Route.collection(collection.id), attributes: [
                "class": "inline-block no-decoration color-blue hover-underline mb--" + (options.featured ? "" : " ms-1")
            ], [.text(collection.title)])]
        } else { coll = [] }
        
        let synopsisClasses: Class = "lh-135 color-gray-40 mv-- text-wrapper" + (
            !options.featured && !options.wide ? " ms-1 hyphens" : "")
        
        let titleClasses: Class = "block lh-110 no-decoration bold color-black hover-underline" + (options.wide ? "ms1" : (options.featured ? "ms2" : ""))
        
        let footerClasses: Class = "color-gray-65" + (!options.wide && !options.featured ? " mt-- ms-1" : "")
        
        let synopsisNode: [Node] = options.synopsis ? [.p(classes: synopsisClasses, [.text(synopsis)])] : [] // todo widow thing
        
        let poster = options.featured ? posterURL(width: 1260, height: 630) : posterURL(width: 590, height: 270)
        
        return Node.article(classes: classes, [
            Node.div(classes: pictureClasses, [
                .link(to: .episode(id, .view(playPosition: nil)), classes: pictureLinkClasses, [
                    Node.div(attributes: ["class": "ratio__container bg-center bg-cover", "style": "background-image: url('\(poster)')"]),
                    Node.div(attributes: ["class": "absolute position-stretch opacity-60 blend-darken gradient-episode-black"]),
                    Node.div(classes: "absolute position-stretch flex flex-column", [
                        Node.div(classes: "mt-auto width-full flex items-center lh-100 ms-1 pa- color-white",
                                 smallIcon + [Node.span(attributes: ["class": "ml-auto bold text-shadow-20"], [.text("\(mediaDuration.minutes)")])] // todo format text
                        )
                    ])
                ] + largeIcon)
            ]),
            Node.div(classes: contentClasses, [
                Node.header(coll + ([
                    Node.h3([Node.link(to: .episode(id, .view(playPosition: nil)), classes: titleClasses, [Node.text(title + (released ? "" : " (unreleased)"))])])
                ] as [Node])),
            ] + synopsisNode + [
                .p(classes: footerClasses, [
                    Node.text("Episode \(number)"),
                    Node.span(attributes: ["class": "ph---"], [.raw("&middot;")]),
                    Node.text(releaseAt.pretty)
                ])
            ]),
        ])
    }
}


extension Episode {
    enum DownloadStatus {
        case notSubscribed
        case teamManager
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
            case .teamManager:
                return "Add yourself as team member to download episode videos."
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
        let videoId = canWatch ? vimeoId : (previewVimeoId ?? 0)
        return .div(classes: "ratio ratio--16/9", [
            .div(classes: "ratio__container", [
                .figure(attributes: ["class":"stretch relative"], [
                    Node.iframe(URL(string: "https://player.vimeo.com/video/\(videoId)\(startTime)")!, attributes: [
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
            
            return Node.a(attributes: ["data-time": "\(entry.0)", "class": wrapperClasses + " items-baseline no-decoration hover-cascade js-episode-seek"], [
                Node.span(attributes: ["class": "hover-cascade__underline"], [.text(entry.title)]),
                Node.span(attributes: ["class": "ml-auto color-orange pl-"], [.text(entry.0.timeString)]),
            ], href: "?t=\(Int(entry.0))")
        }
        
        let items = [(6, title: "Introduction")] + tableOfContents
        
        return .div(classes: "l+|absolute l+|position-stretch stretch width-full flex flex-column", [
            Node.h3(attributes: ["class": "color-blue border-top border-2 pt mb+ flex-none flex items-baseline"], [
                .span(attributes: ["class": "smallcaps"], [.text(canWatch ? "In this episode" : "In the full episode")]),
                .span(attributes: ["class": "ml-auto ms-1 bold"], [.text(mediaDuration.timeString)])
            ]),
            Node.div(classes: "flex-auto overflow-auto border-color-lighten-10 border-1 border-top", [
                Node.ol(attributes: ["class": "lh-125 ms-1 color-white"], items.map { entry in
                    Node.li(attributes: ["class": "border-bottom border-1 border-color-lighten-10"], [
                        item(entry)
                    ])
                })
            ])
        ])
    }
    
    func show(playPosition: Int?, downloadStatus: DownloadStatus, otherEpisodes: [EpisodeWithProgress]) -> Node {
        return Node.withContext { self.show_(context: $0, playPosition: playPosition, downloadStatus: downloadStatus, otherEpisodes: otherEpisodes) }
    }
    
    private func show_(context: STContext, playPosition: Int?, downloadStatus: DownloadStatus, otherEpisodes: [EpisodeWithProgress]) -> Node {
        let canWatch = !subscriptionOnly || context.session.premiumAccess
        
        let scroller = Node.aside(attributes: ["class": "bgcolor-pale-gray pt++ js-scroller"], [
            Node.header(attributes: ["class": "container-h flex items-center justify-between"], [
                Node.div([
                    Node.h3(attributes: ["class": "inline-block bold color-black"], [.text("Recent Episodes")]),
                    Node.link(to: .episodes, attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"], [.text("See All")])
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
            ] + otherEpisodes.map { e in
                Node.div(classes: "flex-110 pr+ min-width-5", [e.episode.render(.init(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: context.session)))])
            })
        ])
        
        func smallBlueH3(_ text: Node) -> Node {
            return Node.h3(classes: "color-blue mb", [Node.span(classes: "smallcaps", [text])])
        }
        
        let linkAttrs: [String:String] = ["target": "_blank", "rel": "external"]

        // nil link displays a "not allowed" span
        func smallH4(_ text: Node, link: LinkTarget?) -> Node {
            return Node.h4(classes: "mb---", [
                link.map { l in
                    Node.link(to: l, classes: "bold color-black hover-underline no-decoration", attributes: linkAttrs, [text])
                } ?? Node.span(classes: "bold color-gray-40 cursor-not-allowed", [text])
            ])
        }
        
        let episodeResource: [[Node]] = self.resources.map { res in
            [
                Node.div(classes: "flex-none mr-", [
                    Node.a(classes: "block bgcolor-orange radius-5 hover-bgcolor-blue", attributes: linkAttrs, [
                        Node.inlineSvg(path: "icon-resource-code.svg", classes: "block icon-40")
                        ], href: res.url.absoluteString)
                ]),
                Node.div(classes: "ms-1 lh-125", [
                    smallH4(.text(res.title), link: res.url),
                    Node.p(classes: "color-gray-50", [.text(res.subtitle)])
                ])
            ]
        }
        let downloadImage = Node.inlineSvg(path: "icon-resource-download.svg", classes: "block icon-40")
        let download: [[Node]] = [
            [
                Node.div(classes: "flex-none mr-", [
                    downloadStatus.allowed
                        ? Node.link(to: Route.episode(id, .download), classes: "block bgcolor-orange radius-5 hover-bgcolor-blue", [downloadImage])
                        : Node.span(classes: "block bgcolor-orange radius-5 cursor-not-allowed", [downloadImage])
                ]),
                Node.div(classes: "ms-1 lh-125", [
                    smallH4(.text("Episode Video"), link: downloadStatus.allowed ? Route.episode(id, .download) : nil),
                    .p(classes: "color-gray-50", [.text(downloadStatus.text)])
                ])
            ]
        ]
        let resourceItems: [[Node]] = episodeResource + download
        let resources: [Node] = canWatch ? [
            Node.section(classes: "pb++", [
                smallBlueH3("Resources"),
            Node.ul(classes: "stack", resourceItems.map { Node.li(classes: "flex", $0)})
            ])
        ] : []
        
        let inCollection: [Node] = primaryCollection.map { coll in
            [
                Node.section(classes: "pb++", [
                    smallBlueH3("In Collection")
                ] +
                coll.render(.init(episodes: true))
                + [
                    Node.p(classes: "ms-1 mt text-right", [
                        Node.link(to: .collections, classes: "no-decoration color-blue hover-cascade", [
                            Node.span(classes: "hover-cascade__border-bottom", ["See All Collections"]),
                            Node.span(classes: "bold", [Node.raw("&rarr;")])
                        ])
                    ])
                ])
            ]
        } ?? []
        let detailItems: [(String,String, URL?)] = [
            ("Released", DateFormatter.fullPretty.string(from: releaseAt), nil)
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
                                Node.link(to: u, classes: "color-gray-15 hover-underline no-decoration", [.text(value)])
                            } ?? .text(value)])
                        ])
                    ])
                })
            ])
        ] : []
        let sidebar: Node = Node.aside(classes: "p-col max-width-7 center stack l+|width-1/3 xl+|width-3/10 l+|flex-auto", resources + inCollection + details)
        let epTitle: [Node] = [
            .p(attributes: ["class": "color-orange ms1"], [
                .link(to: .home, attributes: ["class": "color-inherit no-decoration bold hover-border-bottom"], [.text("Swift Talk")]),
                .text("#" + number.padded)
            ]),
            .h2(attributes: ["class": "ms5 color-white bold mt-- lh-110"], [.text(fullTitle + (released ? "" : " (unreleased)"))]),
        ]
        let guests: [Node] = guestHosts.isEmpty ? [] : [
            .p(classes: "color-white opacity-70 mt-", [
                Node.text("with special \("guest".pluralize(guestHosts.count))")
            ] + guestHosts.map { gh in
                Node.link(to: gh.url, classes: "color-inherit bold no-decoration hover-border-bottom", [
                    Node.text(gh.name)
                ])
            })
        ]
        let header = Node.header(attributes: ["class": "mb++ pb"], epTitle + guests)
        let headerAndPlayer = Node.div(classes: "bgcolor-night-blue pattern-shade-darker", [
            .div(classes: "container l+|pb0 l+|n-mb++", [
                header,
                .div(classes: "l+|flex", [
                    .div(classes: "flex-110 order-2", [
                        player(canWatch: canWatch, playPosition: playPosition)
                    ]),
                    .div(classes: "min-width-5 relative order-1 mt++ l+|mt0 l+|mr++ l+|mb++", [
                        toc(canWatch: canWatch)
                    ])
                ])
            ])
        ])
        
        let episodeUpdates: [Node]
        if let ups = updates, ups.count > 0 {
            episodeUpdates = [
                .div(classes: "text-wrapper mv+", [
                    .aside(classes: "js-expandable border border-1 border-color-subtle-blue bgcolor-pale-blue pa radius-5", [
                        .header(classes: "flex justify-between items-baseline mb-", [
                            .h3(classes: "smallcaps color-blue-darker mb-", [.text("Updates")])
                        ]),
                        .ul(classes: "stack", ups.map { u in
                            .li(classes: "ms-1 media", [
                                .div(classes: "media__image grafs color-blue-darker mr-", [.text("•")]),
                                .div(classes: "media__body links grafs inline-code", [
                                    .markdown(u.text)
                                ])
                            ])
                        }),
                    ])
                ])
            ]
        } else {
            episodeUpdates = []
        }

        let transcriptAvailable: [Node] = [
            context.session.premiumAccess ? .raw("") : .raw(subscriptionPitch),
            .div(classes: "l+|flex l-|stack+++ m-cols", [
                .div(classes: "p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 flex flex-column", [
                    Node.div(classes: "text-wrapper", [
                        Node.div(classes: "lh-140 color-blue-darkest ms1 bold mb+", [
                            .markdown(synopsis),
                        ])
                    ]),
                ] + episodeUpdates + [
                    .div(classes: "flex-auto relative min-height-5", [
                        .div(attributes: ["class": "js-transcript js-expandable z-0", "data-expandable-collapsed": "absolute position-stretch position-nw overflow-hidden", "id": "transcript"], [
                            Node.raw(expandTranscript),
                            Node.div(classes: "c-text c-text--fit-code z-0 js-has-codeblocks", [
                                .raw(highlightedTranscript ?? "No transcript yet.")
                            ])
                        ])
                    ])
                ]),
                sidebar
            ])
        ]
        let noTranscript: [Node] = [
            .div(classes: "bgcolor-pale-blue border border-1 border-color-subtle-blue radius-5 ph pv++ flex flex-column justify-center items-center text-center min-height-6", [
                Node.inlineSvg(path: "icon-blocked.svg"),
                .div(classes: "mv", [
                    .h3(attributes: ["class":"ms1 bold color-blue-darkest"], [.text("This episode is exclusive to Subscribers")]),
                    .p(attributes: ["class": "mt- lh-135 color-blue-darkest opacity-60 max-width-8"], [
                        .text("Become a subscriber to watch future and all \(Episode.subscriberOnly) current subscriber-only episodes, plus enjoy access to episode video downloads and \(teamDiscount)% discount for your team members.")
                    ])
                ]),
                Node.link(to: .signup(.subscribe), attributes: ["class": "button button--themed"], [.text("Become a subscriber")])
            ])
        ]
        
        let scripts: [Node] = (context.session?.user.data.csrfToken).map { token in
            return [
                Node.script(src: "https://player.vimeo.com/api/player.js"),
                Node.script(code: """
                    $(function () {
                        var player = new Vimeo.Player(document.querySelector('iframe'));
                        var playedUntil = 0
                    
                        function postProgress(time) {
                            $.post(\"\(Route.episode(id, .playProgress).absoluteString)\", {
                                \"csrf\": \"\(token.stringValue)\",
                                \"progress": Math.floor(time)
                            }, function(data, status) {
                            });
                        }
                    
                        player.on('timeupdate', function(data) {
                            if (data.seconds > playedUntil + 10) {
                                playedUntil = data.seconds
                                postProgress(playedUntil);
                            }
                        });

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

                        // Catch clicks on timestamps and forward to player
                        $(document).on('click singletap', '.js-episode .js-episode-seek', function (event) {
                            if ($(this).data('time') !== undefined) {
                                player.setCurrentTime($(this).data('time'));
                                player.play();
                                event.preventDefault();
                            }
                        });
                    });
                    """
                )
            ]
        } ?? []
        
        let main: Node = Node.div(classes: "js-episode", [
            headerAndPlayer,
            .div(classes: "bgcolor-white l+|pt++", [
                .div(classes: "container", canWatch ? transcriptAvailable : noTranscript)
            ])
        ])
        
        let data = StructuredData(title: title, description: synopsis, url: Route.episode(id, .view(playPosition: nil)).url, image: posterURL(width: 600, height: 338), type: .video(duration: Int(mediaDuration), releaseDate: releaseAt))
        return LayoutConfig(contents: [main, scroller] + (context.session.premiumAccess ? [] : [subscribeBanner()]), footerContent: scripts, structuredData: data).layout
    }
}

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
<a href="\(Route.signup(.subscribe).path)" class="color-blue no-decoration hover-cascade">
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
        return all.lazy.filter { $0.subscriptionOnly }.count
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
                    """
                ),
                Node.div(classes: "col s+|width-1/2", [
                    Node.ul(attributes: ["class": "stack+ lh-110"], subscriptionBenefits.map { b in
                        Node.li([
                            Node.div(classes: "flag", [
                                Node.div(classes: "flag__image pr color-orange", [
                                    Node.inlineSvg(path: b.icon, attributes: ["class": "svg-fill-current"])
                                ]),
                                Node.div(classes: "flag__body", [
                                    Node.h3(attributes: ["class": "bold color-white mb---"], [Node.text(b.name)]),
                                    Node.p(attributes: ["class": "color-blue-darkest lh-125"], [Node.text(b.description)])
                                ])
                            ])
                        ])
                    })
                ]),
                Node.div(classes: "s+|absolute s+|position-sw col s+|width-1/2", [
                    Node.link(to: .signup(.subscribe), attributes: ["class": "c-button"], [.raw("Pricing &amp; Sign Up")])
                ])
            ])
        ])
    ])
}

