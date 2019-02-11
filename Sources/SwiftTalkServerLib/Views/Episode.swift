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
                .h2(classes: "inline-block lh-100 mb+", [
                    .span(classes: "bold", [
                        .text("\(episodes.count) Episodes")
                    ])
                ])
            ]),
            .ul(classes: "cols s+|cols--2n m+|cols--3n xl+|cols--4n", episodes.map { e in
                .li(classes: "col mb++ width-full s+|width-1/2 m+|width-1/3 xl+|width-1/4", [
                    .withSession { e.episode.render(.init(synopsis: true, watched: e.watched, canWatch: e.episode.canWatch(session: $0))) }
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
        
        let smallIcon: [Node] = options.largeIcon ? [] : [.inlineSvg(classes: "svg-fill-current icon-26", path: iconFile)]
        let largeIconSVGClass: Class = "svg-fill-current" + (options.largeIcon ? "icon-46" : "icon-26")
        let largeIcon: [Node] = options.largeIcon ? [.div(classes: largeIconClasses, [.inlineSvg(classes: largeIconSVGClass, path: iconFile)])] : []
        
        let contentClasses: Class = "flex-auto flex flex-column" +
            (options.wide ? "m+|width-2/3" : "flex-auto justify-center") +
            (!options.featured && !options.wide ? " pt-" : "") +
            (options.featured ? "pa bgcolor-pale-gray radius-5 no-radius-top" : "")
        
        let coll: [Node]
        if options.collection, let collection = primaryCollection {
            coll = [.link(to: Route.collection(collection.id), attributes: [
                "class": "inline-block no-decoration color-blue hover-underline mb--" + (options.featured ? "" : " ms-1")
            ], [.text(collection.title)])]
        } else { coll = [] }
        
        let synopsisClasses: Class = "lh-135 color-gray-40 mv-- text-wrapper" + (
            !options.featured && !options.wide ? " ms-1 hyphens" : "")
        
        let titleClasses: Class = "block lh-110 no-decoration bold color-black hover-underline" + (options.wide ? "ms1" : (options.featured ? "ms2" : ""))
        
        let footerClasses: Class = "color-gray-65" + (!options.wide && !options.featured ? " mt-- ms-1" : "")
        
        let synopsisNode: [Node] = options.synopsis ? [.p(classes: synopsisClasses, [.text(synopsis)])] : [] // todo widow thing
        
        let poster = options.featured ? posterURL(width: 1260, height: 630) : posterURL(width: 590, height: 270)
        
        return .article(classes: classes, [
            .div(classes: pictureClasses, [
                .link(to: .episode(id, .view(playPosition: nil)), classes: pictureLinkClasses, [
                    .div(classes: "ratio__container bg-center bg-cover", attributes: ["style": "background-image: url('\(poster)')"]),
                    .div(classes: "absolute position-stretch opacity-60 blend-darken gradient-episode-black"),
                    .div(classes: "absolute position-stretch flex flex-column", [
                        .div(classes: "mt-auto width-full flex items-center lh-100 ms-1 pa- color-white", smallIcon + [.span(classes: "ml-auto bold text-shadow-20", [.text("\(mediaDuration.minutes)")])]
                        )
                    ])
                ] as [Node] + largeIcon)
            ]),
            .div(classes: contentClasses, [
                Node.header(coll + ([
                    .h3([.link(to: .episode(id, .view(playPosition: nil)), classes: titleClasses, [.text(title + (released ? "" : " (unreleased)"))])])
                ])),
            ] + synopsisNode + [
                .p(classes: footerClasses, [
                    .text("Episode \(number)"),
                    .span(classes: "ph---", [.raw("&middot;")]),
                    .text(releaseAt.pretty)
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
                .figure(classes: "stretch relative", [
                    .iframe(source: URL(string: "https://player.vimeo.com/video/\(videoId)\(startTime)")!, attributes: [
                        "width": "100%",
                        "height": "100%",
                        "webkitallowfullscreen": "",
                        "mozallowfullscreen": "",
                        "allowfullscreen": ""
                    ])
                ] + (canWatch ? [] : [.raw(previewBadge)]))
            ])
        ])
    }
    
    fileprivate func toc(canWatch: Bool) -> Node {
        let wrapperClasses = "flex color-inherit pv"
        
        func item(_ entry: (TimeInterval, title: String)) -> Node {
            guard canWatch else {
                return .span(attributes: ["class": wrapperClasses], [.text(entry.title)])
            }
            
            return .a(href: "?t=\(Int(entry.0))", attributes: ["data-time": "\(entry.0)", "class": wrapperClasses + " items-baseline no-decoration hover-cascade js-episode-seek"], [
                .span(classes: "hover-cascade__underline", [.text(entry.title)]),
                .span(classes: "ml-auto color-orange pl-", [.text(entry.0.timeString)]),
            ])
        }
        
        let items = [(6, title: "Introduction")] + tableOfContents
        
        return .div(classes: "l+|absolute l+|position-stretch stretch width-full flex flex-column", [
            .h3(classes: "color-blue border-top border-2 pt mb+ flex-none flex items-baseline", [
                .span(classes: "smallcaps", [.text(canWatch ? "In this episode" : "In the full episode")]),
                .span(classes: "ml-auto ms-1 bold", [.text(mediaDuration.timeString)])
            ]),
            .div(classes: "flex-auto overflow-auto border-color-lighten-10 border-1 border-top", [
                .ol(classes: "lh-125 ms-1 color-white", items.map { entry in
                    .li(classes: "border-bottom border-1 border-color-lighten-10", [
                        item(entry)
                    ])
                })
            ])
        ])
    }
    
    func show(playPosition: Int?, downloadStatus: DownloadStatus, otherEpisodes: [EpisodeWithProgress]) -> Node {
        return .withSession { self.show_(session: $0, playPosition: playPosition, downloadStatus: downloadStatus, otherEpisodes: otherEpisodes) }
    }
    
    private func show_(session: Session?, playPosition: Int?, downloadStatus: DownloadStatus, otherEpisodes: [EpisodeWithProgress]) -> Node {
        let canWatch = !subscriptionOnly || session.premiumAccess
        
        let scroller = Node.aside(classes: "bgcolor-pale-gray pt++ js-scroller", [
            .header(classes: "container-h flex items-center justify-between", [
                .div([
                    .h3(classes: "inline-block bold color-black", [.text("Recent Episodes")]),
                    .link(to: .episodes, classes: "inline-block ms-1 ml- color-blue no-decoration hover-underline", [.text("See All")])
                ]),
                .div(classes: "js-scroller-buttons flex items-center", [
                    .button(classes: "scroller-button no-js-hide js-scroller-button-left ml-", attributes: ["label": "Scroll left"], [
                        .inlineSvg(classes: "icon-16 color-white svg-fill-current block", path: "icon-arrow-16-left.svg", preserveAspectRatio: "xMinYMid meet")
                    ]),
                    .button(classes: "scroller-button no-js-hide js-scroller-button-right ml-", attributes: ["label": "Scroll right"], [
                        .inlineSvg(classes: "icon-16 color-white svg-fill-current block", path: "icon-arrow-16.svg", preserveAspectRatio: "xMinYMid meet")
                    ])
                ])
            ]),
            .div(classes: "flex scroller js-scroller-container p-edges pt pb++", [
                .div(classes: "scroller__offset flex-none")
            ] + otherEpisodes.map { e in
                .div(classes: "flex-110 pr+ min-width-5", [e.episode.render(.init(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: session)))])
            })
        ])
        
        func smallBlueH3(_ text: Node) -> Node {
            return .h3(classes: "color-blue mb", [.span(classes: "smallcaps", [text])])
        }
        
        let linkAttrs: [String:String] = ["target": "_blank", "rel": "external"]

        // nil link displays a "not allowed" span
        func smallH4(_ text: Node, link: LinkTarget?) -> Node {
            return .h4(classes: "mb---", [
                link.map { l in
                    .link(to: l, classes: "bold color-black hover-underline no-decoration", attributes: linkAttrs, [text])
                } ?? .span(classes: "bold color-gray-40 cursor-not-allowed", [text])
            ])
        }
        
        let episodeResource: [[Node]] = self.resources.map { res in
            [
                .div(classes: "flex-none mr-", [
                    .a(classes: "block bgcolor-orange radius-5 hover-bgcolor-blue", href: res.url.absoluteString, attributes: linkAttrs, [
                        .inlineSvg(classes: "block icon-40", path: "icon-resource-code.svg")
                    ])
                ]),
                .div(classes: "ms-1 lh-125", [
                    smallH4(.text(res.title), link: res.url),
                    .p(classes: "color-gray-50", [.text(res.subtitle)])
                ])
            ]
        }
        let downloadImage = Node.inlineSvg(classes: "block icon-40", path: "icon-resource-download.svg")
        let download: [[Node]] = [
            [
                .div(classes: "flex-none mr-", [
                    downloadStatus.allowed
                        ? .link(to: Route.episode(id, .download), classes: "block bgcolor-orange radius-5 hover-bgcolor-blue", [downloadImage])
                        : .span(classes: "block bgcolor-orange radius-5 cursor-not-allowed", [downloadImage])
                ]),
                .div(classes: "ms-1 lh-125", [
                    smallH4(.text("Episode Video"), link: downloadStatus.allowed ? Route.episode(id, .download) : nil),
                    .p(classes: "color-gray-50", [.text(downloadStatus.text)])
                ])
            ]
        ]
        let resourceItems: [[Node]] = episodeResource + download
        let resources: [Node] = canWatch ? [
            .section(classes: "pb++", [
                smallBlueH3("Resources"),
                .ul(classes: "stack", resourceItems.map { .li(classes: "flex", $0)})
            ])
        ] : []
        
        let inCollection: [Node] = primaryCollection.map { coll in
            [
                .section(classes: "pb++", [
                    smallBlueH3("In Collection")
                ] +
                coll.render(.init(episodes: true))
                + [
                    .p(classes: "ms-1 mt text-right", [
                        .link(to: .collections, classes: "no-decoration color-blue hover-cascade", [
                            .span(classes: "hover-cascade__border-bottom", ["See All Collections"]),
                            .span(classes: "bold", [.raw("&rarr;")])
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
        let details: [Node] = canWatch ? [
            .div(classes: "pb++", [
                smallBlueH3("Episode Details"),
                .ul(classes: "ms-1 stack", detailItems.map { key, value, url in
                    .li([
                        .dl(classes: "flex justify-between", [
                            .dt(classes: "color-gray-60", [.text(key)]),
                            .dd(classes: "color-gray-15 text-right", [url.map { u in
                                .link(to: u, classes: "color-gray-15 hover-underline no-decoration", [.text(value)])
                            } ?? .text(value)])
                        ])
                    ])
                })
            ])
        ] : []
        let sidebar = Node.aside(classes: "p-col max-width-7 center stack l+|width-1/3 xl+|width-3/10 l+|flex-auto", resources + inCollection + details)
        let epTitle: [Node] = [
            .p(classes: "color-orange ms1", [
                .link(to: .home, classes: "color-inherit no-decoration bold hover-border-bottom", [.text("Swift Talk")]),
                .text("#" + number.padded)
            ]),
            .h2(classes: "ms5 color-white bold mt-- lh-110", [.text(fullTitle + (released ? "" : " (unreleased)"))]),
        ]
        let guests: [Node] = guestHosts.isEmpty ? [] : [
            .p(classes: "color-white opacity-70 mt-", [
                .text("with special \("guest".pluralize(guestHosts.count))")
            ] + guestHosts.map { gh in
                .link(to: gh.url, classes: "color-inherit bold no-decoration hover-border-bottom", [
                    .text(gh.name)
                ])
            })
        ]
        let header = Node.header(classes: "mb++ pb", epTitle + guests)
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
            session.premiumAccess || session?.isTeamManager == true ? .raw("") : subscriptionPitch,
            .div(classes: "l+|flex l-|stack+++ m-cols", [
                .div(classes: "p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 flex flex-column", [
                    .div(classes: "text-wrapper", [
                        .div(classes: "lh-140 color-blue-darkest ms1 bold mb+", [
                            .markdown(synopsis),
                        ])
                    ]),
                ] + episodeUpdates + [
                    .div(classes: "flex-auto relative min-height-5", [
                        .div(classes: "js-transcript js-expandable z-0", attributes: ["data-expandable-collapsed": "absolute position-stretch position-nw overflow-hidden", "id": "transcript"], [
                            .raw(expandTranscript),
                            .div(classes: "c-text c-text--fit-code z-0 js-has-codeblocks", [
                                .raw(highlightedTranscript ?? "No transcript yet.")
                            ])
                        ])
                    ])
                ]),
                sidebar
            ])
        ]
        
        func noTranscript(text: String, buttonTitle: String, target: Route) -> [Node] {
            return [
                .div(classes: "bgcolor-pale-blue border border-1 border-color-subtle-blue radius-5 ph pv++ flex flex-column justify-center items-center text-center min-height-6", [
                    .inlineSvg(path: "icon-blocked.svg"),
                    .div(classes: "mv", [
                        .h3(classes: "ms1 bold color-blue-darkest", [.text("This episode is exclusive to Subscribers")]),
                        .p(classes: "mt- lh-135 color-blue-darkest opacity-60 max-width-8", [
                            .text(text)
                        ])
                    ]),
                    .link(to: target, classes: "button button--themed", [.text(buttonTitle)])
                ])
            ]
        }
        
        let noTranscriptAccess = session?.isTeamManager == true
            ? noTranscript(text: "Team manager accounts don't have access to Swift Talk content by default. To enable content access on this account, please add yourself as a team member.", buttonTitle: "Manage Team Members", target: .account(.teamMembers))
            : noTranscript(text: "Become a subscriber to watch future and all \(Episode.subscriberOnly) current subscriber-only episodes, plus enjoy access to episode video downloads and \(teamDiscount)% discount for your team members.", buttonTitle: "Become a subscriber", target: .signup(.subscribe))

        let scripts: [Node] = (session?.user.data.csrfToken).map { token in
            return [
                .script(src: "https://player.vimeo.com/api/player.js"),
                .script(code: """
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
        
        let main = Node.div(classes: "js-episode", [
            headerAndPlayer,
            .div(classes: "bgcolor-white l+|pt++", [
                .div(classes: "container", canWatch ? transcriptAvailable : noTranscriptAccess)
            ])
        ])
        
        let data = StructuredData(title: title, description: synopsis, url: Route.episode(id, .view(playPosition: nil)).url, image: posterURL(width: 600, height: 338), type: .video(duration: Int(mediaDuration), releaseDate: releaseAt))
        return LayoutConfig(contents: [main, scroller] + (session.premiumAccess ? [] : [subscribeBanner()]), footerContent: scripts, structuredData: data).layout
    }
}

let expandTranscript = """
<div class="no-js-hide absolute height-4 gradient-fade-to-white position-stretch-h position-s ph z-1" data-expandable-expanded="hide">
<div class="absolute position-s width-full text-wrapper text-center">
<button type="button" class="js-expandable-trigger smallcaps button radius-full ph+++">Continue reading…</button>
</div>
</div>
"""

let subscriptionPitch = Node.div(classes: "bgcolor-pale-blue border border-1 border-color-subtle-blue color-blue-darkest pa+ radius-5 mb++", [
    .div(classes: "max-width-8 center text-center", [
        .h3(classes: "mb-- bold lh-125", ["This episode is freely available thanks to the support of our subscribers"]),
        .p(classes: "lh-135", [
            .span(classes: "opacity-60", ["Subscribers get exclusive access to new and all previous subscriber-only episodes, video downloads, and 30% discount for team members."]),
            .link(to: Route.signup(.subscribe), classes: "color-blue no-decoration hover-cascade", [
                .span(classes: "hover-cascade__border-bottom", ["Become a Subscriber"]),
                .span(classes: "bold", [.raw(" &rarr;")])
            ])
        ])
    ])
])


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
    return .aside(classes: "bgcolor-blue", [
        .div(classes: "container", [
            .div(classes: "cols relative s-|stack+", [
                .raw("""
                    <div class="col s+|width-1/2 relative">
                        <p class="smallcaps color-orange mb">Unlock Full Access</p>
                        <h2 class="color-white bold ms3">Subscribe to Swift Talk</h2>
                    </div>
                    """
                ),
                .div(classes: "col s+|width-1/2", [
                    .ul(classes: "stack+ lh-110", subscriptionBenefits.map { b in
                        .li([
                            .div(classes: "flag", [
                                .div(classes: "flag__image pr color-orange", [
                                    .inlineSvg(classes: "svg-fill-current", path: b.icon)
                                ]),
                                .div(classes: "flag__body", [
                                    .h3(classes: "bold color-white mb---", [.text(b.name)]),
                                    .p(classes: "color-blue-darkest lh-125", [.text(b.description)])
                                ])
                            ])
                        ])
                    })
                ]),
                .div(classes: "s+|absolute s+|position-sw col s+|width-1/2", [
                    .link(to: .signup(.subscribe), classes: "c-button", [.raw("Pricing &amp; Sign Up")])
                ])
            ])
        ])
    ])
}

