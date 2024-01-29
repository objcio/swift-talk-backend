//
//  Episode.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1
import WebServer
import HTML

func index(_ episodes: [EpisodeWithProgress]) -> Node {
    return LayoutConfig(pageTitle: "All Episodes".constructTitle, contents: [
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
    ], projectColor: nil).layout
}

extension Episode {
    var previewCard: HTML.Node {
        div(class: "episode-video-preview-container") {
            img(alt: "", class: "", loading: "lazy", sizes: "100vw", src: posterURL(width: 980, height: Int(980/(16.0/9))).absoluteString, width: "980")
            div(class: "play-video-button center")
            div(class: "episode-video-preview-duration") { "\(mediaDuration.timeString)" }
        }
    }
    
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
        return .withInput { env in
            
            let content = newEpisodeDetail(downloadStatus: downloadStatus, playPosition: playPosition, otherEpisodes: otherEpisodes)
            let data = StructuredData(title: title, description: synopsis, url: Route.episode(id, .view(playPosition: nil)).url, image: posterURL(width: 600, height: 338), type: .video(duration: Int(mediaDuration), releaseDate: releaseAt))
            
            let scripts: [Node] = [
                .script(src: "https://player.vimeo.com/api/player.js"),
                .script(code: """
                    function playerLoaded() {
                        var playedUntil = 0
                    
                        function postProgress(time) {
                            var httpRequest = new XMLHttpRequest();
                            httpRequest.open('POST', "\(Route.episode(id, .playProgress).absoluteString)");
                            httpRequest.send(JSON.stringify({
                                "csrf": "\(env.csrf.string)",
                                "progress": Math.floor(time)
                            }));
                    
                        }
                    
                        player.on('timeupdate', function(data) {
                            if (data.seconds > playedUntil + 10) {
                                playedUntil = data.seconds
                                postProgress(playedUntil);
                            }
                        });
                    };
                    
                    window.addEventListener('DOMContentLoaded', function () {
                        window.player = new Vimeo.Player(document.querySelector('iframe'));
                        playerLoaded();
                    
                        var items = document.querySelector('.episode-transcript').querySelectorAll("a[href^='#']");
                        items.forEach(function (item) {
                            if (/^\\d+$/.test(item.hash.slice(1)) && /^\\d{1,2}(:\\d{2}){1,2}$/.test(item.innerHTML)) {
                                var time = parseInt(item.hash.slice(1));
                                item.dataset.time = time;
                                item.setAttribute('href', '?t='+time);
                                item.classList.add('js-episode-seek', 'js-transcript-cue');
                            }
                        });
                    
                        // Catch clicks on timestamps and forward to player
                        document.querySelectorAll('.js-episode-seek').forEach(function(el) {
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
            
            return LayoutConfig(pageTitle: title.constructTitle, contents: [content], footerContent: scripts, structuredData: data, projectColor: theProject?.color).layout
        }
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

extension Episode {
    fileprivate func newEpisodeDetail(downloadStatus: DownloadStatus, playPosition: Int?, otherEpisodes: [EpisodeWithProgress]) -> HTML1.Node<STRequestEnvironment> {
        .withInput { env in
            let p = theProject!
            let pEps = p.allEpisodes.scoped(for: env.session?.user.data)
            let idx = pEps.firstIndex(of: self)!
            let next = idx < pEps.endIndex-1 ? pEps[idx+1] : nil
            let prev = idx > pEps.startIndex ? pEps[idx-1] : nil
            let canAccess = canWatch(session: env.session)
            
            return div(class: "episode-detail-content-container") {
                div(class: "episode-video-section") {
                    div(class: "save-share-buttons-container mobile") {
                        a(class: "save-button mobile w-button", href: "#")
                        a(class: "share-button mobile w-button", href: "#")
                    }
                    div(class: "episode-details-header") {
                        div(class: "nano-text small purple episode-count-date project-color") {
                            "Episode 335 · Dec 16 2022"
                        }
                        div(class: "episode-name-export-share-buttons-container") {
                            h2(class: "h2 dark") { title }
                            div(class: "save-share-buttons-container") {
                                a(class: "save-button w-button", href: "#")
                                a(class: "share-button w-button", href: "#")
                            }
                        }
                        a(class: "project-title-button small w-button project-color", href: Route.project(p.id).absoluteString) {
                            "project:"
                            span(class: "text-span-17") { p.title }
                            span(class: "text-span-3") { "→" }
                        }
                    }
                    div(class: "episode-video-container") {
                        div(class: "vimeo-container") {
                            div(class: "video w-video w-embed", style: "padding-top:56.27659574468085%") {
                                let startTime = playPosition.map { "#t=\($0)s" } ?? ""
                                let videoId = canAccess ? vimeoId : (previewVimeoId ?? 0)
                                iframe(allowfullscreen: false, class: "embedly-embed", src: "https://player.vimeo.com/video/\(videoId)\(startTime)")
                            }
                        }
                        div(class: "previous-next-buttons-container") {
                            if let prev {
                                a(class: "secondary-button-small _75-opacity w-button", href: Route.episode(prev.id, .view(playPosition: nil)).absoluteString) {
                                    span(class: "text-span-4") {
                                        "←"
                                    }
                                    if next == nil {
                                        "Previous episode in project"
                                    } else {
                                        "Previous"
                                    }
                                }
                            }
                            if let next {
                                a(class: "secondary-button-small _75-opacity w-button", href: Route.episode(next.id, .view(playPosition: nil)).absoluteString) {
                                    "Next episode in project"
                                    span(class: "text-span-5") { "→" }
                                }
                            }
                        }
                    }
                    a(class: "project-title-button small mobile w-button project-color", href: Route.project(p.id).absoluteString) {
                        "project:"
                        span(class: "text-span-17") { p.title }
                        span(class: "text-span-3") { "→" }
                    }
                }
                div(class: "episode-content-section") {
                    div(class: "episode-content-details") {
                        div(class: "episode-sidebar") {
                            div(class: "sidebar-component-container in-this-episode") {
                                div(class: "nano-text half-white") {
                                    canAccess ? "In this episode" : "In the full episode"
                                }
                                div(class: "chapters-container") {
                                    let items = [(6, title: "Introduction")] + tableOfContents
                                    items.map { entry in
                                        a(class: "episode-chapter-link w-inline-block js-episode-seek", href: "?t=\(Int(entry.0))", customAttributes: ["data-time": "\(Int(entry.0))"]) {
                                            div(class: "chapter-name") { entry.title }
                                            div(class: "chapter-timestamp project-color") { entry.0.timeString }
                                        }
                                    }
                                }
                            }
                            div(class: "sidebar-component-container resources") {
                                div(class: "nano-text half-white") {
                                    "Resources"
                                }
                                div(class: "resources-container") {
                                    resources.map { r in
                                        div(class: "resource-container") {
                                            div(class: "resource-image-container") {
                                                img(alt: "", class: "resource-image", loading: "lazy", src: "/assets/images/{-}.png", width: "27.5")
                                            }
                                            div(class: "resource-details-container") {
                                                h6(class: "h6 dark small _75-opacity resource-name") {
                                                    r.title
                                                }
                                                div(class: "p4 half-white resource-detail") {
                                                    r.subtitle
                                                }
                                            }
                                        }
                                    }
                                    div(class: "resource-container") {
                                        div(class: "resource-image-container") {
                                            img(alt: "", class: "resource-image", loading: "lazy", src: "/assets/images/arrow-down.png", width: "17.5")
                                        }
                                        div(class: "resource-details-container") {
                                            h6(class: "h6 dark small _75-opacity resource-name") {
                                                "Download Episode"
                                            }
                                            div(class: "p4 half-white resource-detail") { downloadStatus.text }
                                        }
                                    }
                                }
                            }
                            div(class: "sidebar-component-container in-this-project") {
                                div(class: "nano-text half-white") {
                                    "In this project"
                                }
                                div(class: "project-sidebar-episodes-container") {
                                    pEps.enumerated().map { idx, ep in
                                        div(class: "sidebar-episode-container") {
                                            div(class: "sidebar-episode-details") {
                                                let current = ep == self ? "current" : ""
                                                h6(class: "h6 episode-count \(current)") { "\(idx)." }
                                                div(class: "episode-name \(current)") { ep.title }
                                            }
                                            let progress = otherEpisodes.first { $0.episode == ep }
                                            let href = Route.episode(ep.id, .view(playPosition: progress?.progress)).absoluteString
                                            if progress?.watched == true {
                                                a(href: href)
                                                img(alt: "", height: "20", loading: "lazy", src: "/assets/images/checkmark-circle.png", width: "20")
                                            } else {
                                                a(class: "episode-play-button w-button", href: href)
                                            }
                                        }
                                    }
                                }
                                a(class: "secondary-button-small _75-opacity w-button", href: Route.home.absoluteString) {
                                    "View all projects"
                                    span(class: "text-span-5") {
                                        "→"
                                    }
                                }
                            }
                            div(class: "sidebar-component-container credits") {
                                let detailItems: [(String,String, URL?)] = [
                                    ("Released", DateFormatter.fullPretty.string(from: releaseAt), nil)
                                ] + theCollaborators.sorted(by: { $0.role < $1.role }).map { coll in
                                    (coll.role.name, coll.name, .some(coll.url))
                                }
                                div(class: "nano-text half-white") {
                                    "Credits"
                                }
                                div(class: "chapters-container") {
                                    detailItems.map { key, value, url in
                                        div(class: "episode-credit-container") {
                                            div(class: "p4 _75-opacity") { key }
                                            div(class: "p4 purple project-color") {
                                                if let url {
                                                    a(class: "project-color", href: url.absoluteString) { value }
                                                } else {
                                                    value
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        div(class: "episode-transcript-container") {
                            if canAccess {
                                div(class: "episode-transcript-content") {
                                    h4(class: "h5 dark") { synopsis }
                                    div(class: "transcript-container") {
                                        div(class: "body dark episode-transcript") {
                                            Swim.Node.raw(highlightedTranscript ?? "No transcript yet.")
                                        }
                                    }
                                }
                            }
                            if let next {
                                div(class: "button-container") {
                                    a(class: "secondary-button-with-image w-button", href: Route.episode(next.id, .view(playPosition: nil)).absoluteString) {
                                        "Next Episode in project: \(p.title)"
                                        span(class: "text-span-14") {
                                            "→"
                                        }
                                    }
                                }
                            }
                        }
                        div(class: "episode-sidebar mobile") {
                            div(class: "sidebar-component-container in-this-project mobile") {
                                div(class: "nano-text half-white") {
                                    "In this project"
                                }
                                div(class: "project-sidebar-episodes-container") {
                                    pEps.enumerated().map { (idx, ep) in
                                        div(class: "sidebar-episode-container") {
                                            div(class: "sidebar-episode-details") {
                                                h6(class: "h6 dark small episode-count") { "\(idx)." }
                                                div(class: "p4 episode-name current") { ep.title }
                                            }
                                            img(alt: "", height: "20", loading: "lazy", src: "/assets/images/checkmark-circle.png", width: "20")
                                            a(class: "episode-play-button w-button", href: Route.episode(ep.id, .view(playPosition: nil)).absoluteString)
                                        }
                                    }
                                }
                                a(class: "secondary-button-small _75-opacity w-button", href: Route.home.absoluteString) {
                                    "View all projects"
                                    span(class: "text-span-5") {
                                        "→"
                                    }
                                }
                            }
                            div(class: "sidebar-component-container credits mobile") {
                                div(class: "nano-text half-white") {
                                    "Credits"
                                }
                                div(class: "chapters-container") {
                                    div(class: "episode-credit-container") {
                                        div(class: "p4 _75-opacity") {
                                            "Released"
                                        }
                                        div(class: "p4 purple") {
                                            "July 02, 2021"
                                        }
                                    }
                                    div(class: "episode-credit-container") {
                                        div(class: "p4 _75-opacity") {
                                            "Hosts"
                                        }
                                        div(class: "p4 purple") {
                                            "Chris Eidhof,"
                                            br()
                                            "Florian Kugler"
                                        }
                                    }
                                    div(class: "episode-credit-container") {
                                        div(class: "p4 _75-opacity") {
                                            "Transcript"
                                        }
                                        div(class: "p4 purple") {
                                            "Juul Spee"
                                        }
                                    }
                                    div(class: "episode-credit-container") {
                                        div(class: "p4 _75-opacity") {
                                            "Copy Editing"
                                        }
                                        div(class: "p4 purple") {
                                            "Natalye Childress"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }.asOldNode
        }
    }

}

