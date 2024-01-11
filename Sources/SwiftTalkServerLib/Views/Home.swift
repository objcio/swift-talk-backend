//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1
import HTML

fileprivate var newHomeBody: HTML1.Node<STRequestEnvironment> {
    HTML1.Node.withInput { env in
        div(class: "swift-talk-content-container") {
            div(class: "swift-talk-hero-section") {
                div(class: "swift-talk-hero-container") {
                    h1(class: "h1 center dark mobile") {
                        span(class: "h1-span blue") {
                            "Swift Talk,"
                        }
                        "our weekly video series on swift programming."
                    }
                    div(class: "p2 center mobile dark") {
                        "Live-coding and discussion videos complete with transcripts and source code to try yourself. Watch some for free, subscribe to watch everything."
                    }
                    if env.session == nil {
                        div(class: "button-container github") {
                            a(class: "primary-button w-button", href: "#") {
                                "Sign in with GitHub"
                            }
                        }
                    }
                }
                div(class: "mobile-log-in-subscribe-buttons-container") {
                    a(class: "primary-button grow w-button", href: "#") {
                        "Subscribe"
                    }
                    a(class: "secondary-button grow w-button", href: "#") {
                        "Log in"
                    }
                }
            }
            div(class: "swift-talk-latest-episode-section") {
                div(class: "swift-talk-latest-episode-header") {
                    h2(class: "h2 dark") {
                        "Latest episode"
                    }
                }
                div(class: "swift-talk-latest-episode-container") {
                    div(class: "latest-episode-container") {
                        div(class: "swift-talks-latest-episode") {
                            img(alt: "", class: "latest-episode-preview-image", loading: "eager", sizes: "(max-width: 479px) 93vw, (max-width: 767px) 87vw, (max-width: 991px) 90vw, 980px", src: "/images/temp-video-frame.png", srcset: "/images/temp-video-frame-p-500.png 500w, /images/temp-video-frame.png 600w", width: "300")
                            div(class: "play-video-button center")
                        }
                    }
                    div(class: "swift-talk-latest-episode-details-container") {
                        a(class: "latest-episode-container w-inline-block", href: "/episode-detail") {
                            div(class: "swift-talks-latest-episode-details") {
                                div(class: "swift-talks-latest-episode-details-header") {
                                    div(class: "nano-text medium-purple small") {
                                        "Episode 335 · Dec 16 2022"
                                    }
                                    h4(class: "h4 dark") {
                                        "Views and notes"
                                    }
                                }
                                div(class: "h5 dark _75-opacity") {
                                    "We use our sticky modifier to implement a tabbed scroll view with a sticky picker. We create a Model class that has a counterproperty, and we conform the class to ObservableObject, which we import from the Combine framework."
                                }
                            }
                        }
                        a(class: "swift-talks-latest-episode-project-container w-inline-block", href: "/swift-talks-project") {
                            div(class: "nano-text medium-purple small") {
                                "project: building a watch complication"
                                span(class: "text-span-2") {
                                    "→"
                                }
                            }
                        }
                    }
                }
            }
            div(class: "filter-search-section") {
                a(class: "swift-talk-filter-button projects w-button", href: "#") {
                    "Projects"
                }
                a(class: "swift-talk-filter-button episodes w-button", href: "#") {
                    "Episodes"
                }
                div(class: "swift-talk-search-container") {
                    img(alt: "", class: "image-16", loading: "lazy", src: "/images/magnifying-glass.png", width: "20")
                    form(action: "/search", class: "search w-form") {
                        label(class: "field-label", for: "search") {
                            "Search"
                        }
                        input(class: "search-input w-input", id: "search", maxlength: "256", name: "query", placeholder: "Search…", required: false, type: "search")
                        input(class: "search-button w-button", type: "submit", value: "Search")
                    }
                }
                a(class: "swift-talk-sort-button w-button", href: "#") {
                    "Sort by: most recent"
                    span(class: "chevron-down-span") {
                        ">"
                    }
                }
            }
            div(class: "swift-talk-episodes-section") {
                div(class: "episodes-project-container") {
                    a(class: "project-title-button w-button", href: "/swift-talks-project") {
                        "project: building a watch complication"
                        span(class: "text-span-3") {
                            "→"
                        }
                    }
                    div(class: "project-episodes-container") {
                        div(class: "episode-dropdown w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {
                            div(class: "episode-dropdown-toggle w-dropdown-toggle") {
                                div(class: "episode-dropdown-container") {
                                    div(class: "episode-left-container") {
                                        a(class: "episode-play-button w-button", href: "/episode-detail")
                                        div(class: "p3 dark") {
                                            "Views and nodes"
                                        }
                                    }
                                    div(class: "episode-right-container") {
                                        div(class: "nano-text medium-purple small") {
                                            "Episode 335 · Dec 16 2022"
                                        }
                                        img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/images/chevron-down.png", width: "24")
                                    }
                                }
                                div(class: "episode-dropdown-container-mobile") {
                                    div(class: "episode-left-container") {
                                        a(class: "episode-play-button w-button", href: "#")
                                    }
                                    div(class: "episode-center-container") {
                                        div(class: "p3 dark") {
                                            "Views and nodes"
                                        }
                                        div(class: "nano-text medium-purple small") {
                                            "Episode 335 · Dec 16 2022"
                                        }
                                    }
                                    div(class: "episode-right-container") {
                                        img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/images/chevron-down.png", width: "24")
                                    }
                                }
                            }
                            nav(class: "episode-dropdown-list w-dropdown-list") {
                                div(class: "episode-more-details-container") {
                                    div(class: "episode-summary-container") {
                                        div(class: "p3 dark _50-opacity") {
                                            "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                                        }
                                    }
                                    img(alt: "", class: "image-15", loading: "lazy", sizes: "100vw", src: "/images/temp-video-frame-large.png", srcset: "/images/temp-video-frame-large-p-500.png 500w, /images/temp-video-frame-large-p-800.png 800w, /images/temp-video-frame-large-p-1080.png 1080w, /images/temp-video-frame-large-p-1600.png 1600w, /images/temp-video-frame-large.png 1960w", width: "980")
                                }
                            }
                        }
                        div(class: "episode-dropdown w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {
                            div(class: "episode-dropdown-toggle w-dropdown-toggle") {
                                div(class: "episode-dropdown-container") {
                                    div(class: "episode-left-container") {
                                        a(class: "episode-play-button w-button", href: "#")
                                        div(class: "p3 dark") {
                                            "Scroll view with tabs"
                                        }
                                    }
                                    div(class: "episode-right-container") {
                                        div(class: "nano-text medium-purple small") {
                                            "Episode 335 · Dec 16 2022"
                                        }
                                        img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/images/chevron-down.png", width: "24")
                                    }
                                }
                                div(class: "episode-dropdown-container-mobile") {
                                    div(class: "episode-left-container") {
                                        a(class: "episode-play-button w-button", href: "#")
                                    }
                                    div(class: "episode-center-container") {
                                        div(class: "p3 dark") {
                                            "Views and nodes"
                                        }
                                        div(class: "nano-text medium-purple small") {
                                            "Episode 335 · Dec 16 2022"
                                        }
                                    }
                                    div(class: "episode-right-container") {
                                        img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/images/chevron-down.png", width: "24")
                                    }
                                }
                            }
                            nav(class: "episode-dropdown-list w-dropdown-list") {
                                div(class: "episode-more-details-container") {
                                    div(class: "p3 dark _50-opacity") {
                                        "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                                    }
                                    img(alt: "", class: "image-15", loading: "lazy", sizes: "100vw", src: "/images/temp-video-frame-large.png", srcset: "/images/temp-video-frame-large-p-500.png 500w, /images/temp-video-frame-large-p-800.png 800w, /images/temp-video-frame-large-p-1080.png 1080w, /images/temp-video-frame-large-p-1600.png 1600w, /images/temp-video-frame-large.png 1960w", width: "980")
                                }
                            }
                        }
                    }
                }
            }
            div(class: "swift-talk-projects-section") {
                div(class: "project-container") {
                    div(class: "project-cover-container purple") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image", loading: "lazy", src: "/images/apple-watch.png", width: "210")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Building a Watch compilation"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small purple") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container yellow-orange") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image-bottom-align", loading: "lazy", src: "/images/photo-picker-grey-border.png", width: "215")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Building a photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small yellow-orange") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container orange") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image", loading: "lazy", src: "/images/watch-screen.png", width: "210")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Building a photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small orange") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container pink") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image-bottom-align", loading: "lazy", src: "/images/photo-picker-black-border.png", width: "214.5")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Landscape view photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small pink") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "subscriptions-container") {
                    div(class: "subscriptions-header") {
                        h2(class: "h2 dark center") {
                            "Support Swift Talk with a subscription"
                        }
                        div(class: "p2 center dark") {
                            "Access the entire archive of Swift Talks, download videos for offline viewing, and help keep us producing new episodes."
                        }
                    }
                    div(class: "subscription-choices-container") {
                        div(class: "subscription-container") {
                            div(class: "subscription-content") {
                                div(class: "subscription-price-container") {
                                    h1(class: "h1 center dark") {
                                        "€15"
                                    }
                                    div(class: "caption-text-capitalised") {
                                        "Per month"
                                    }
                                }
                                div(class: "button-container") {
                                    a(class: "primary-button subscribe-button w-button", href: "#") {
                                        "Subscribe"
                                    }
                                }
                            }
                        }
                        div(class: "subscription-container") {
                            div(class: "subscription-savings-absolute-container") {
                                div(class: "caption-text small") {
                                    "Save €30"
                                }
                            }
                            div(class: "subscription-content") {
                                div(class: "subscription-price-container") {
                                    h1(class: "h1 center dark") {
                                        "€150"
                                    }
                                    div(class: "caption-text-capitalised") {
                                        "Per year"
                                    }
                                }
                                div(class: "button-container") {
                                    a(class: "primary-button subscribe-button w-button", href: "#") {
                                        "Subscribe"
                                    }
                                }
                            }
                        }
                    }
                    div(class: "subscription-container team") {
                        div(class: "subscription-content team") {
                            div(class: "team-subscription-container") {
                                h2(class: "h2 center dark") {
                                    "Team subscription"
                                }
                                div(class: "body center large _75-white") {
                                    "Our team subscription includes a 30% discount and comes with a central account that lets you manage billing and access for your entire team."
                                }
                            }
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container yellow-orange") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image-bottom-align", loading: "lazy", src: "/images/photo-picker-grey-border.png", width: "215")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Building a photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small yellow-orange") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container orange") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image", loading: "lazy", src: "/images/watch-screen.png", width: "210")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Building a photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small orange") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
                div(class: "project-container") {
                    div(class: "project-cover-container pink") {
                        div(class: "play-video-button")
                        img(alt: "", class: "project-cover-image-bottom-align", loading: "lazy", src: "/images/photo-picker-black-border.png", width: "214.5")
                    }
                    div(class: "project-details-container") {
                        div(class: "project-details-header") {
                            h4(class: "h4 dark") {
                                "Landscape view photo grid"
                            }
                            div(class: "body dark") {
                                "We re-implement parts of SwiftUI's state system to better understand how SwiftUI manages state and which views get executed when."
                            }
                        }
                        div(class: "nano-text small pink") {
                            "8 Episodes · 2h 49min · 12 december 2022"
                        }
                    }
                }
            }
        }.asOldNode
    }
}


func renderHome(episodes: [EpisodeWithProgress]) -> Node {
    let metaDescription = "A weekly video series on Swift programming by Chris Eidhof and Florian Kugler. objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development."
    var recentNodes: [Node] = [
        .header(class: "mb+", [
            .h2(class: "inline-block bold color-black", ["Recent Episodes"]),
            .link(to: .episodes, class: "inline-block ms-1 ml- color-blue no-decoration hover-under", ["See All"])
        ])
    ]
    let projects: [Node] = Episode.allGroupedByProject.map { pv in
        switch pv {
        case let .single(ep):
            return Node.p([
                Node.pre("S: \(ep.number) \(ep.title)")
            ])
        case let .multiple(eps):
            return Node.p([
                Node.pre("M: \(eps[0].theProject!.title): \(eps.map { "\($0.number) \($0.title)" }.joined(separator: ", "))")
            ])
        }
    }
    let projectsView = Node.section(class: "container", projects)

    if episodes.count >= 5 {
        let slice = episodes[0..<5]
        let featured = slice[0]
        recentNodes.append(.withSession { session in
            .div(class: "m-cols flex flex-wrap", [
                .div(class: "mb++ p-col width-full l+|width-1/2", [
                    featured.episode.render(Episode.ViewOptions(featured: true, synopsis: true, watched: featured.watched, canWatch: featured.episode.canWatch(session: session)))
                ]),
                .div(class: "p-col width-full l+|width-1/2", [
                    .div(class: "s+|cols s+|cols--2n",
                        slice.dropFirst().map { e in
                            .div(class: "mb++ s+|col s+|width-1/2", [
                                e.episode.render(Episode.ViewOptions(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: session)))
                            ])
                        }
                    )
                ])
            ])
        })
    }
    let recentEpisodes = Node.section(class: "container", recentNodes)
    let collections = Node.section(class: "container", [
        .header(class: "mb+", [
            .h2(class: "inline-block bold lh-100 mb---", [.text("Collections")]),
            .link(to: .collections, class: "inline-block ms-1 ml- color-blue no-decoration hover-underline", ["Show Contents"]),
            .p(class: "lh-125 color-gray-60", [
                "Browse all Swift Talk episodes by topic."
            ])
            ]),
        .ul(class: "cols s+|cols--2n l+|cols--3n", Collection.all.map { coll in
            .li(class: "col width-full s+|width-1/2 l+|width-1/3 mb++", coll.render())
        })
    ])
    return LayoutConfig(contents: [newHomeBody /*projectsView*/], description: metaDescription).layout
}

