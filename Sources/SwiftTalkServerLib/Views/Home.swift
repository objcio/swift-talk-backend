//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1
import HTML

extension Project {
    var card: HTML.Node {
        div(class: "project-container") {
            div(class: "project-cover-container purple") {
                a(href: Route.project(id).absoluteString) {
                    div(class: "play-video-button")
                }
                img(alt: "", class: "project-cover-image", loading: "lazy", src: "/assets/images/apple-watch.png", width: "210")
            }
            div(class: "project-details-container") {
                div(class: "project-details-header") {
                    h4(class: "h4 dark") { title }
                    div(class: "body dark") { description }
                }
                div(class: "nano-text small", style: "color: \(color)") {
                    let eps = allEpisodes
                    "\(eps.count) episodes · \(eps.totalDuration.hoursAndMinutes) · \(eps.first?.releaseAt.pretty ?? "<unkown>")"
                }
            }
        }
    }
}

extension Episode {
    fileprivate func homeCard(playPosition: Int?) -> HTML.Node {
        div(class: "swift-talk-latest-episode-section") {
            div(class: "swift-talk-latest-episode-header") {
                h2(class: "h2 dark") {
                    "Latest episode"
                }
            }
            div(class: "swift-talk-latest-episode-container", style: (theProject?.color).map { "--project-color: \($0);" }) {
                div(class: "latest-episode-container") {
                    a(href: Route.episode(id, .view(playPosition: playPosition)).absoluteString) {
                        div(class: "swift-talks-latest-episode") {
                            img(alt: "", class: "latest-episode-preview-image", loading: "eager", sizes: "(max-width: 479px) 93vw, (max-width: 767px) 87vw, (max-width: 991px) 90vw, 980px", src: posterURL(width: 1260, height: 630).absoluteString, width: "300")
                            div(class: "play-video-button center")
                        }
                    }
                }
                div(class: "swift-talk-latest-episode-details-container") {
                    a(class: "latest-episode-container w-inline-block", href: Route.episode(id, .view(playPosition: nil)).absoluteString) {
                        div(class: "swift-talks-latest-episode-details") {
                            div(class: "swift-talks-latest-episode-details-header") {
                                div(class: "nano-text medium-purple small project-color") {
                                    "Episode \(number) · \(releaseAt.pretty)"
                                }
                                h4(class: "h4 dark") {
                                    title
                                }
                            }
                            div(class: "h5 dark _75-opacity") {
                                synopsis
                            }
                        }
                    }
                    if let p = theProject {
                        a(class: "swift-talks-latest-episode-project-container w-inline-block", href: Route.project(p.id).absoluteString) {
                            div(class: "nano-text medium-purple small project-color") {
                                "project: \(p.title)"
                                span(class: "text-span-2") {
                                    "→"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

fileprivate func header(env: STRequestEnvironment) -> HTML.Node {
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
}

fileprivate func tabs(env: STRequestEnvironment) -> HTML.Node {
    div(class: "filter-search-section") {
        a(class: "swift-talk-filter-button projects w-button", href: "#") {
            "Projects"
        }
        a(class: "swift-talk-filter-button episodes w-button", href: "#") {
            "Episodes"
        }
        div(class: "swift-talk-search-container") {
            img(alt: "", class: "image-16", loading: "lazy", src: "/assets/images/magnifying-glass.png", width: "20")
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
}

func newHome(episodes: [EpisodeWithProgress], projects: [Project], grouped: [ProjectView], monthly: Plan, yearly: Plan) -> HTML1.Node<STRequestEnvironment> {
    let content: HTML1.Node<STRequestEnvironment> = HTML1.Node.withInput { env in
        div(class: "swift-talk-content-container") {
            header(env: env)
            if let latest = episodes.first {
                latest.episode.homeCard(playPosition: latest.progress)
            }
            div(class: "swift-talk-latest-episode-header") {
                h2(class: "h2 dark") {
                    "Previous episodes"
                }
            }
//            div(class: "swift-talk-projects-section") {
//                let scoped = projects.scoped(for: env.session?.user.data)
//                scoped.prefix(4).map { $0.card }
//                if env.session?.premiumAccess != true {
//                    div(class: "subscriptions-container") {
//                        div(class: "subscriptions-header") {
//                            h2(class: "h2 dark center") {
//                                "Support Swift Talk with a subscription"
//                            }
//                            div(class: "p2 center dark") {
//                                "Access the entire archive of Swift Talks, download videos for offline viewing, and help keep us producing new episodes."
//                            }
//                        }
//                        div(class: "subscription-choices-container") {
//                            monthly.box(monthly: nil, coupon: nil, team: false, session: nil)
//                            yearly.box(monthly: monthly, coupon: nil, team: false, session: nil)
//                        }
//                        teamSubscriptionBanner()
//                    }
//                }
//                scoped.suffix(from: 4).map { $0.card }
//            }
            div(class: "swift-talk-episodes-section") {
                let progress = Dictionary(uniqueKeysWithValues: episodes.compactMap { pair in
                    pair.progress.map { ((pair.episode.number, $0)) }
                })
                let scoped = grouped.scoped(for: env.session?.user.data)
                scoped.map { p in
                    div(class: "episodes-project-container", style: (p.episodes.first?.theProject?.color).map { "--project-color: \($0);" }) {
                        switch p {
                        case let .multiple(eps):
                            let project = eps[0].theProject!
                            a(class: "project-title-button w-button", href: Route.project(project.id).absoluteString, customAttributes: ["onmouseover": "this.style.color=pSBC(0.35, this.style.color);", "onmouseout": "this.style.color=\"\(project.color)\";"]) {
                                "project: \(project.title)"
                                span(class: "text-span-3") {
                                    "→"
                                }
                            }
                        case .single: 
                            span(class: "project-title-button w-button") { "standalone episode" }
                        }
                        div(class: "project-episodes-container") {
                            p.episodes.scoped(for: env.session?.user.data).map { episode in
                                div(class: "episode-dropdown w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {
                                    div(class: "episode-dropdown-toggle w-dropdown-toggle") {
                                        div(class: "episode-dropdown-container") {
                                            div(class: "episode-left-container") {
                                                a(class: "episode-play-button w-button", href: Route.episode(episode.id, .view(playPosition: progress[episode.number])).absoluteString)
                                                div(class: "p3 dark") { episode.title }
                                            }
                                            div(class: "episode-right-container") {
                                                div(class: "nano-text small medium-purple project-color") {
                                                    "#\(episode.number) · \(DateFormatter.withYear.string(from: episode.releaseAt))"
                                                }
                                                img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/assets/images/chevron-down.png", width: "24")
                                            }
                                        }
                                        div(class: "episode-dropdown-container-mobile") {
                                            div(class: "episode-left-container") {
                                                a(class: "episode-play-button w-button", href: "#")
                                            }
                                            div(class: "episode-center-container") {
                                                div(class: "p3 dark") { episode.title }
                                                div(class: "nano-text medium-purple small") {
                                                    "Episode \(episode.number) · \(episode.releaseAt.pretty)"
                                                }
                                                div(class: "episode-right-container") {
                                                    img(alt: "", class: "dropdown-chevron", loading: "lazy", src: "/assets/images/chevron-down.png", width: "24")
                                                }
                                            }
                                        }
                                    }
                                    nav(class: "episode-dropdown-list w-dropdown-list") {
                                        a(href: Route.episode(episode.id, .view(playPosition: nil)).absoluteString) {
                                            div(class: "episode-more-details-container") {
                                                div(class: "episode-summary-container") {
                                                    div(class: "p3 dark _50-opacity") { episode.synopsis }
                                                }
                                                episode.previewCard
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }.asOldNode
    }
            
    return LayoutConfig(contents: [content], description: "A weekly video series on Swift programming by Chris Eidhof and Florian Kugler. objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development.", projectColor: nil).layout
}
