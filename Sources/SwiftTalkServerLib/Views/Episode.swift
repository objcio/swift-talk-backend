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
        .div(class: "container pb0", [
            .div([
                .h2(class: "inline-block lh-100 mb+", [
                    .span(class: "bold", [
                        "\(episodes.count) Episodes"
                    ])
                ])
            ]),
            .ul(class: "cols s+|cols--2n m+|cols--3n xl+|cols--4n", episodes.map { e in
                .li(class: "col mb++ width-full s+|width-1/2 m+|width-1/3 xl+|width-1/4", [
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
        let `class`: Class = "flex flex-column width-full" + // normal
            (options.wide ? "max-width-6 m+|max-width-none m+|flex-row" : "") + // wide
            (options.featured ? "min-height-full hover-scale transition-all transition-transform" : "") // featured
        let pictureClasses: Class = options.wide ? "flex-auto mb- m+|width-1/3 m+|order-2 m+|mb0 m+|pl++" : "flex-none"
        
        let pictureLinkClasses: Class = "block ratio radius-3 overflow-hidden" +
            (options.featured ? "ratio--2/1 radius-5 no-radius-bottom" : " ratio--22/10 hover-scale transition-all transition-transform")
        
        let largeIconClasses: Class = "absolute position-stretch flex justify-center items-center color-white" + (options.canWatch ? "hover-scale-1.25x transition-all transition-transform" : "")
        
        let smallIcon: [Node] = options.largeIcon ? [] : [.inlineSvg(class: "svg-fill-current icon-26", path: iconFile)]
        let largeIconSVGClass: Class = "svg-fill-current" + (options.largeIcon ? "icon-46" : "icon-26")
        let largeIcon: [Node] = options.largeIcon ? [.div(class: largeIconClasses, [.inlineSvg(class: largeIconSVGClass, path: iconFile)])] : []
        
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
        
        let synopsisNode: [Node] = options.synopsis ? [.p(class: synopsisClasses, [.text(synopsis)])] : [] // todo widow thing
        
        let poster = options.featured ? posterURL(width: 1260, height: 630) : posterURL(width: 590, height: 270)
        
        return .article(class: `class`, [
            .div(class: pictureClasses, [
                .link(to: .episode(id, .view(playPosition: nil)), class: pictureLinkClasses, [
                    .div(class: "ratio__container bg-center bg-cover", attributes: ["style": "background-image: url('\(poster)')"]),
                    .div(class: "absolute position-stretch opacity-60 blend-darken gradient-episode-black"),
                    .div(class: "absolute position-stretch flex flex-column", [
                        .div(class: "mt-auto width-full flex items-center lh-100 ms-1 pa- color-white", smallIcon + [.span(class: "ml-auto bold text-shadow-20", ["\(mediaDuration.minutes)"])]
                        )
                    ])
                ] as [Node] + largeIcon)
            ]),
            .div(class: contentClasses, [
                Node.header(coll + ([
                    .h3([.link(to: .episode(id, .view(playPosition: nil)), class: titleClasses, [.text(title + (released ? "" : " (unreleased)"))])])
                ])),
            ] + synopsisNode + [
                .p(class: footerClasses, [
                    "Episode \(number)",
                    .span(class: "ph---", [.raw("&middot;")]),
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
        return .div(class: "ratio ratio--16/9", [
            .div(class: "ratio__container", [
                .figure(class: "stretch relative", [
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
                .span(class: "hover-cascade__underline", [.text(entry.title)]),
                .span(class: "ml-auto color-orange pl-", [.text(entry.0.timeString)]),
            ])
        }
        
        let items = [(6, title: "Introduction")] + tableOfContents
        
        return .div(class: "l+|absolute l+|position-stretch stretch width-full flex flex-column", [
            .h3(class: "color-blue border-top border-2 pt mb+ flex-none flex items-baseline", [
                .span(class: "smallcaps", [.text(canWatch ? "In this episode" : "In the full episode")]),
                .span(class: "ml-auto ms-1 bold", [.text(mediaDuration.timeString)])
            ]),
            .div(class: "flex-auto overflow-auto border-color-lighten-10 border-1 border-top", [
                .ol(class: "lh-125 ms-1 color-white", items.map { entry in
                    .li(class: "border-bottom border-1 border-color-lighten-10", [
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
        
        let scroller = Node.aside(class: "bgcolor-pale-gray pt++", [
            .header(class: "container-h flex items-center justify-between", [
                .div([
                    .h3(class: "inline-block bold color-black", ["Recent Episodes"]),
                    .link(to: .episodes, class: "inline-block ms-1 ml- color-blue no-decoration hover-underline", ["See All"])
                ]),
            ]),
            .div(class: "flex scroller p-edges pt pb++", [
                .div(class: "scroller__offset flex-none")
            ] + otherEpisodes.map { e in
                .div(class: "flex-110 pr+ min-width-5", [e.episode.render(.init(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: session)))])
            })
        ])
        
        func smallBlueH3(_ text: Node) -> Node {
            return .h3(class: "color-blue mb", [.span(class: "smallcaps", [text])])
        }
        
        let linkAttrs: [String:String] = ["target": "_blank", "rel": "external"]

        // nil link displays a "not allowed" span
        func smallH4(_ text: Node, link: LinkTarget?) -> Node {
            return .h4(class: "mb---", [
                link.map { l in
                    .link(to: l, class: "bold color-black hover-underline no-decoration", attributes: linkAttrs, [text])
                } ?? .span(class: "bold color-gray-40 cursor-not-allowed", [text])
            ])
        }
        
        let episodeResource: [[Node]] = self.resources.map { res in
            [
                .div(class: "flex-none mr-", [
                    .a(class: "block bgcolor-orange radius-5 hover-bgcolor-blue", href: res.url.absoluteString, attributes: linkAttrs, [
                        .inlineSvg(class: "block icon-40", path: "icon-resource-code.svg")
                    ])
                ]),
                .div(class: "ms-1 lh-125", [
                    smallH4(.text(res.title), link: res.url),
                    .p(class: "color-gray-50", [.text(res.subtitle)])
                ])
            ]
        }
        let downloadImage = Node.inlineSvg(class: "block icon-40", path: "icon-resource-download.svg")
        let download: [[Node]] = [
            [
                .div(class: "flex-none mr-", [
                    downloadStatus.allowed
                        ? .link(to: Route.episode(id, .download), class: "block bgcolor-orange radius-5 hover-bgcolor-blue", [downloadImage])
                        : .span(class: "block bgcolor-orange radius-5 cursor-not-allowed", [downloadImage])
                ]),
                .div(class: "ms-1 lh-125", [
                    smallH4("Episode Video", link: downloadStatus.allowed ? Route.episode(id, .download) : nil),
                    .p(class: "color-gray-50", [.text(downloadStatus.text)])
                ])
            ]
        ]
        let resourceItems: [[Node]] = episodeResource + download
        let resources: [Node] = canWatch ? [
            .section(class: "pb++", [
                smallBlueH3("Resources"),
                .ul(class: "stack", resourceItems.map { .li(class: "flex", $0)})
            ])
        ] : []
        
        let inCollection: [Node] = primaryCollection.map { coll in
            [
                .section(class: "pb++", [
                    smallBlueH3("In Collection")
                ] +
                coll.render(.init(episodes: true))
                + [
                    .p(class: "ms-1 mt text-right", [
                        .link(to: .collections, class: "no-decoration color-blue hover-cascade", [
                            .span(class: "hover-cascade__border-bottom", ["See All Collections"]),
                            .span(class: "bold", [.raw("&rarr;")])
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
            .div(class: "pb++", [
                smallBlueH3("Episode Details"),
                .ul(class: "ms-1 stack", detailItems.map { key, value, url in
                    .li([
                        .dl(class: "flex justify-between", [
                            .dt(class: "color-gray-60", [.text(key)]),
                            .dd(class: "color-gray-15 text-right", [url.map { u in
                                .link(to: u, class: "color-gray-15 hover-underline no-decoration", [.text(value)])
                            } ?? .text(value)])
                        ])
                    ])
                })
            ])
        ] : []
        let sidebar = Node.aside(class: "p-col max-width-7 center stack l+|width-1/3 xl+|width-3/10 l+|flex-auto", resources + inCollection + details)
        let epTitle: [Node] = [
            .p(class: "color-orange ms1", [
                .link(to: .home, class: "color-inherit no-decoration bold hover-border-bottom", ["Swift Talk"]),
                "# \(number.padded)"
            ]),
            .h2(class: "ms5 color-white bold mt-- lh-110", [.text(fullTitle + (released ? "" : " (unreleased)"))]),
        ]
        let guests: [Node] = guestHosts.isEmpty ? [] : [
            .p(class: "color-white opacity-70 mt-", [
                "with special \("guest".pluralize(guestHosts.count))"
            ] + guestHosts.map { gh in
                .link(to: gh.url, class: "color-inherit bold no-decoration hover-border-bottom", [
                    .text(gh.name)
                ])
            })
        ]
        let header = Node.header(class: "mb++ pb", epTitle + guests)
        let headerAndPlayer = Node.div(class: "bgcolor-night-blue pattern-shade-darker", [
            .div(class: "container l+|pb0 l+|n-mb++", [
                header,
                .div(class: "l+|flex", [
                    .div(class: "flex-110 order-2", [
                        player(canWatch: canWatch, playPosition: playPosition)
                    ]),
                    .div(class: "min-width-5 relative order-1 mt++ l+|mt0 l+|mr++ l+|mb++", [
                        toc(canWatch: canWatch)
                    ])
                ])
            ])
        ])
        
        let episodeUpdates: [Node]
        if let ups = updates, ups.count > 0 {
            episodeUpdates = [
                .div(class: "text-wrapper mv+", [
                    .aside(class: "js-expandable border border-1 border-color-subtle-blue bgcolor-pale-blue pa radius-5", [
                        .header(class: "flex justify-between items-baseline mb-", [
                            .h3(class: "smallcaps color-blue-darker mb-", ["Updates"])
                        ]),
                        .ul(class: "stack", ups.map { u in
                            .li(class: "ms-1 media", [
                                .div(class: "media__image grafs color-blue-darker mr-", ["•"]),
                                .div(class: "media__body links grafs inline-code", [
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
            .div(class: "l+|flex l-|stack+++ m-cols", [
                .div(class: "p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 flex flex-column", [
                    .div(class: "text-wrapper", [
                        .div(class: "lh-140 color-blue-darkest ms1 bold mb+", [
                            .markdown(synopsis),
                        ])
                    ]),
                ] + episodeUpdates + [
                    .div(class: "flex-auto relative min-height-5", [
                        .div(class: "js-transcript js-expandable z-0", attributes: ["data-expandable-collapsed": "absolute position-stretch position-nw overflow-hidden", "id": "transcript"], [
                            .div(class: "c-text c-text--fit-code z-0 js-has-codeblocks", [
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
                .div(class: "bgcolor-pale-blue border border-1 border-color-subtle-blue radius-5 ph pv++ flex flex-column justify-center items-center text-center min-height-6", [
                    .inlineSvg(path: "icon-blocked.svg"),
                    .div(class: "mv", [
                        .h3(class: "ms1 bold color-blue-darkest", ["This episode is exclusive to Subscribers"]),
                        .p(class: "mt- lh-135 color-blue-darkest opacity-60 max-width-8", [
                            .text(text)
                        ])
                    ]),
                    .link(to: target, class: "button button--themed", [.text(buttonTitle)])
                ])
            ]
        }
        
        let noTranscriptAccess = session?.isTeamManager == true
            ? noTranscript(text: "Team manager accounts don't have access to Swift Talk content by default. To enable content access on this account, please add yourself as a team member.", buttonTitle: "Manage Team Members", target: .account(.teamMembers))
            : noTranscript(text: "Become a subscriber to watch future and all \(Episode.subscriberOnly) current subscriber-only episodes, plus enjoy access to episode video downloads and \(teamDiscount)% discount for your team members.", buttonTitle: "Become a subscriber", target: .signup(.subscribe(planName: nil)))

        var scripts: [Node] = [
            .script(src: "https://player.vimeo.com/api/player.js"),
            .script(code: """
                window.addEventListener('DOMContentLoaded', function () {
                    window.player = new Vimeo.Player(document.querySelector('iframe'));
                    var items = document.querySelector('.js-transcript').querySelectorAll("a[href^='#']");
                    items.forEach(function (item) {
                        if (/^\\d+$/.test(item.hash.slice(1)) && /^\\d{1,2}(:\\d{2}){1,2}$/.test(item.innerHTML)) {
                            var time = parseInt(item.hash.slice(1));
                            item.dataset.time = time;
                            item.setAttribute('href', '?t='+time);
                            item.classList.add('js-episode-seek', 'js-transcript-cue');
                        }
                    });

                    // Catch clicks on timestamps and forward to player
                    document.querySelectorAll('.js-episode .js-episode-seek').forEach(function(el) {
                        el.addEventListener('click', function (event) {
                            var time = event.target.dataset.time;
                            if (time !== undefined) {
                                player.setCurrentTime(time);
                                player.play();
                                event.preventDefault();
                            }
                        })
                    });

                });
                """
            )
        ]
        if let token = session?.user.data.csrfToken {
            scripts.append(
                .script(code: """
                    $(function () {
                        var playedUntil = 0
                    
                        function postProgress(time) {
                            $.post(\"\(Route.episode(id, .playProgress).absoluteString)\", {
                                \"csrf\": \"\(token.stringValue ?? "")\",
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
                    });
                    """
                )
            )
        }
        
        let main = Node.div(class: "js-episode", [
            headerAndPlayer,
            .div(class: "bgcolor-white l+|pt++", [
                .div(class: "container", canWatch ? transcriptAvailable : noTranscriptAccess)
            ])
        ])
        
        let data = StructuredData(title: title, description: synopsis, url: Route.episode(id, .view(playPosition: nil)).url, image: posterURL(width: 600, height: 338), type: .video(duration: Int(mediaDuration), releaseDate: releaseAt))
        return LayoutConfig(contents: [main, scroller] + (session.premiumAccess ? [] : [subscribeBanner()]), footerContent: scripts, structuredData: data).layout
    }
}

let subscriptionPitch = Node.div(class: "bgcolor-pale-blue border border-1 border-color-subtle-blue color-blue-darkest pa+ radius-5 mb++", [
    .div(class: "max-width-8 center text-center", [
        .h3(class: "mb-- bold lh-125", ["This episode is freely available thanks to the support of our subscribers"]),
        .p(class: "lh-135", [
            .span(class: "opacity-60", ["Subscribers get exclusive access to new and all previous subscriber-only episodes, video downloads, and 30% discount for team members."]),
            .link(to: Route.signup(.subscribe(planName: nil)), class: "color-blue no-decoration hover-cascade", [
                .span(class: "hover-cascade__border-bottom", ["Become a Subscriber"]),
                .span(class: "bold", [.raw(" &rarr;")])
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
    return .aside(class: "bgcolor-blue", [
        .div(class: "container", [
            .div(class: "cols relative s-|stack+", [
                .raw("""
                    <div class="col s+|width-1/2 relative">
                        <p class="smallcaps color-orange mb">Unlock Full Access</p>
                        <h2 class="color-white bold ms3">Subscribe to Swift Talk</h2>
                    </div>
                    """
                ),
                .div(class: "col s+|width-1/2", [
                    .ul(class: "stack+ lh-110", subscriptionBenefits.map { b in
                        .li([
                            .div(class: "flag", [
                                .div(class: "flag__image pr color-orange", [
                                    .inlineSvg(class: "svg-fill-current", path: b.icon)
                                ]),
                                .div(class: "flag__body", [
                                    .h3(class: "bold color-white mb---", [.text(b.name)]),
                                    .p(class: "color-blue-darkest lh-125", [.text(b.description)])
                                ])
                            ])
                        ])
                    })
                ]),
                .div(class: "s+|absolute s+|position-sw col s+|width-1/2", [
                    .link(to: .signup(.subscribe(planName: nil)), class: "c-button", [.raw("Pricing &amp; Sign Up")])
                ])
            ])
        ])
    ])
}

