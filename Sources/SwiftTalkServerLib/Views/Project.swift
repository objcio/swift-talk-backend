import Foundation
import HTML1
import HTML


extension Project {
    func show(episodes: [EpisodeWithProgress]) -> HTML1.Node<STRequestEnvironment> {
        return .withInput { env in
            let currentRoute = env.route
            let imageURL = Route.staticFile(path: ["images", "collections", "\(self.title)@4x.png"]).url // TODO
            let structuredData = StructuredData(title: "Swift Talk Project: \(self.title)", description: self.description, url: currentRoute.url, image: imageURL, type: .website)
            
            let content = div(class: "swift-talk-project-content-container", style: "--project-color: \(color);") {
                div(class: "episode-section") {
                    div(class: "project-header-container") {
                        div(class: "project-cover-container purple swift-talk-project") {
                            div(class: "play-video-button")
                            img(alt: "", class: "project-cover-image", loading: "lazy", src: "/assets/images/apple-watch.png", width: "210")
                        }
                        div(class: "project-details-container") {
                            div(class: "project-details-header") {
                                h2(class: "h2 dark") { title }
                                div(class: "body dark") { description }
                            }
                            div(class: "nano-text small purple project-color") {
                                "\(episodes.count) \("Episode".pluralize(episodes.count)) · \(episodes.map { $0.episode }.totalDuration.hoursAndMinutes) · \(DateFormatter.fullPretty.string(from: episodes.last!.episode.releaseAt))"
                            }
                        }
                    }
                    div(class: "episodes-container") {
                        episodes.enumerated().map { (idx, ep) in
                            let episode = ep.episode
                            return a(href: Route.episode(episode.id, .view(playPosition: ep.progress)).absoluteString) {
                                div(class: "episode-container") {
                                    div(class: "episode-details") {
                                        h4(class: "h4 dark") { "\(idx+1). \(episode.title)" }
                                        div(class: "nano-text small purple project-color") {
                                            "episode \(episode.number) · \(DateFormatter.withYear.string(from: episode.releaseAt))"
                                        }
                                        div(class: "body dark") { episode.synopsis }
                                    }
                                    div(class: "episode-video-preview-container") {
                                        img(alt: "", class: "", loading: "lazy", sizes: "100vw", src: episode.posterURL(width: 980, height: Int(980/(16.0/9))).absoluteString, width: "980")
                                        div(class: "play-video-button center")
                                    }
                                }
                            }
                        }
                    }
                }
                div(class: "more-projects-section") {
                    div(class: "more-projects-header") {
                        h2(class: "h2 dark") {
                            "More projects"
                        }
                    }
                    div(class: "more-projects-container") {
                        Project.all.scoped(for: env.session?.user.data).prefix(3).map { $0.card }
                    }
                }
            }.asOldNode
            
            return LayoutConfig(pageTitle: self.title.constructTitle, contents: [content], structuredData: structuredData).layout
        }
    }
}

//extension Collection {
//    struct ViewOptions {
//        var episodes: Bool = false
//        var whiteBackground: Bool = false
//        init(episodes: Bool = false, whiteBackground: Bool = false) {
//            self.episodes = episodes
//            self.whiteBackground = whiteBackground
//        }
//    }
//    func render(_ options: ViewOptions = ViewOptions()) -> [Node] {
//        let figureStyle = "background-color: " + (options.whiteBackground ? "#FCFDFC" : "#F2F4F2")
//        let eps: (Session?) -> [Episode] = { self.episodes(for: $0?.user.data) }
//        let episodes_: [Node] = options.episodes ? [
//            .withSession { session in
//                .ul(class: "mt-",
//                    eps(session).map { e in
//                        let title = e.title(in: self)
//                        return .li(class: "flex items-baseline justify-between ms-1 line-125", [
//                            .span(class: "nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45", [
//                                .link(to: .episode(e.id, .view(playPosition: nil)), class: "no-decoration color-inherit hover-underline", [.text(title + (e.released ? "" : " (unreleased)"))])
//                                ]),
//                            .span(class: "flex-none pl- pv- color-gray-70", [.text(e.mediaDuration.timeString)])
//                        ])
//                    }
//                )
//            }
//        ] : []
//        return [
//            .article(attributes: [:], [
//                .link(to: .collection(id), [
//                    .figure(attributes: ["class": "mb-", "style": figureStyle], [
//                        .hashedImg(class: "block width-full height-auto", src: artwork)
//                    ]),
//                ]),
//                .div(class: "flex items-center pt--", [
//                    .h3([.link(to: .collection(id), class: "inline-block lh-110 no-decoration bold color-black hover-under", [.text(title)])])
//                ] + (new ? [
//                    .span(class: "flex-none label smallcaps color-white bgcolor-blue nowrap ml-", ["New"])
//                ] : [])),
//                .withSession { session in
//                    let e = eps(session)
//                    return .p(class: "ms-1 color-gray-55 lh-125 mt--", [
//                        "\(e.count) \("Episode".pluralize(e.count))",
//                        .span(class: "ph---", [.raw("&middot;")]),
//                        .text(e.totalDuration.hoursAndMinutes)
//                    ])
//                }
//            ] + episodes_)
//        ]
//    }
//}
//
//
