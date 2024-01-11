//
//  Layout.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1
import WebServer
import HTML

let basicPageTitle: String = "Swift Talk - objc.io"
extension String {
    var constructTitle: String {
        return "\(self) - \(basicPageTitle)"
    }
}

extension HTML.Node {
    var raw: String {
        var str: String = ""
        write(to: &str)
        return str
    }
    
    var asOldNode: HTML1.Node<STRequestEnvironment> {
        .raw(raw)
    }
}

struct LayoutConfig {
    var pageTitle: String
    var contents: [Node]
    var metaDescription: String?
    var footerContent: [Node]
    var structuredData: StructuredData?
    var includeRecurlyJS: Bool = false
    
    init(pageTitle: String = basicPageTitle, contents: [Node], description: String? = nil, footerContent: [Node] = [], structuredData: StructuredData? = nil, includeRecurlyJS: Bool = false) {
        self.pageTitle = pageTitle
        self.contents = contents
        self.metaDescription = description
        self.footerContent = footerContent
        self.structuredData = structuredData
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
    (URL(string: "https://www.objc.io/workshops/swiftui")!, "SwiftUI Workshop"),
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
            .stylesheet(href: "/assets/stylesheets/normalize.css"),
            .stylesheet(href: "/assets/stylesheets/webflow.css"),
            .stylesheet(href: "/assets/stylesheets/objc-io-redesign.webflow.css"),
//            .hashedStylesheet(href: "/assets/stylesheets/application.css"),
            includeRecurlyJS ? .script(src: "https://js.recurly.com/v4/recurly.js") : .none,
//            googleAnalytics,
        ] + structured)
        
        let header = HTML1.Node.withInput { env in
            HTML.div(class: "navbar dark w-nav", role: "banner", customAttributes: ["data-animation": "default", "data-collapse": "small", "data-duration": "200", "data-easing": "ease", "data-easing2": "ease"]) {
                div(class: "nav-container w-container") {
                    div(class: "nav-content") {
                        a(class: "nav-logo-link-block w-inline-block", href: "https://www.objc.io") {
                            img(alt: "", class: "nav-logo", height: "30", loading: "lazy", src: "/images/logo-letters-dark.png")
                            div(class: "mobile-logo-container") {
                                div(class: "mobile-logo-column") {
                                    img(alt: "", class: "mobile-logo-image", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                                }
                                div(class: "mobile-logo-column") {
                                    img(alt: "", class: "mobile-logo-image right", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                                }
                            }
                            div(class: "logo-animation-container") {
                                div(class: "logo-animation-column-container") {
                                    div(class: "logo-animation-left-container") {
                                        img(alt: "", class: "logo-animation-left-image", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                                        img(alt: "", class: "logo-animation-left-image", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                                    }
                                }
                                div(class: "logo-animation-column-container") {
                                    div(class: "logo-animation-right-container") {
                                        img(alt: "", class: "logo-animation-right-image", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                                        img(alt: "", class: "logo-animation-right-image", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                                    }
                                }
                            }
                        }
                        nav(class: "nav-menu dark w-nav-menu", role: "navigation") {
                            a(class: "nav-link dark workshops underline-animation w-nav-link", href: "https://www.objc.io/workshops") {
                                "Workshops"
                            }
                            a(class: "nav-link dark swift-talk underline-animation w-nav-link w--current", href: "https://talk.objc.io", customAttributes: ["aria-current": "page"]) {
                                "Swift Talk"
                            }
                            a(class: "nav-link dark books underline-animation w-nav-link", href: "https://www.objc.io/books") {
                                "Books"
                            }
                            div(class: "login-subscribe-buttons-container") {
                                if let _ = env.session {
                                    a(class: "log-in-button w-button", href: Route.account(.logout).path) {
                                        "Log out"
                                    }
                                    a(class: "subscribe-button w-button", href: Route.account(.profile).path) {
                                        "Account"
                                    }
                                } else {
                                    a(class: "log-in-button w-button", href: Route.login(.login(continue: env.route)).path) {
                                        "Log in"
                                    }
                                    a(class: "subscribe-button w-button", href: Route.signup(.subscribe(planName: nil)).path) {
                                        "Subscribe"
                                    }
                                }
                            }
                        }
                        div(class: "menu-button dark w-nav-button") {
                            div(class: "menu-button-text dark") {
                                "Menu"
                            }
                        }
                    }
                }
            }.asOldNode
        }
            
        var bodyChildren: [Node] = [
            header,
            .main(
                contents
            )
        ]
        // these are appends because of compile time
        bodyChildren.append(footer)
        bodyChildren.append(contentsOf: footerContent)
        let body = Node.body(attributes: ["class": "body-dark"], bodyChildren)
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
//            googleAnalytics,
        ] + structured)
        let linkClasses: Class = "no-decoration color-inherit hover-color-black mr"
        let body = Node.body(attributes: ["class": "theme-"/* + theme*/], [
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

//let googleAnalytics = Node.raw("""
//<script async src="https://www.googletagmanager.com/gtag/js?id=UA-40809116-1"></script>
//<script>
//  window.dataLayer = window.dataLayer || [];
//  function gtag(){dataLayer.push(arguments);}
//  gtag('js', new Date());
//
//  gtag('config', 'UA-40809116-1');
//</script>
//""")

fileprivate let footer: HTML1.Node<STRequestEnvironment> = HTML.div(class: "footer dark") {
    div(class: "footer-container") {

        div(class: "footer-company-info") {

            div(class: "footer-logo") {
                img(alt: "", class: "footer-logo-letters", height: "30", loading: "lazy", src: "/images/logo-letters-dark.png")

                div(class: "mobile-logo-container") {

                    div(class: "mobile-logo-column footer") {
                        img(alt: "", class: "mobile-logo-image", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                    }

                    div(class: "mobile-logo-column footer") {
                        img(alt: "", class: "mobile-logo-image right", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                    }

                }

                div(class: "logo-animation-container footer") {

                    div(class: "logo-animation-column-container footer") {

                        div(class: "logo-animation-left-container footer") {
                            img(alt: "", class: "logo-animation-left-image footer", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                            img(alt: "", class: "logo-animation-left-image footer", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                        }

                    }

                    div(class: "logo-animation-column-container footer") {

                        div(class: "logo-animation-right-container footer") {
                            img(alt: "", class: "logo-animation-right-image footer", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                            img(alt: "", class: "logo-animation-right-image footer", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                        }

                    }

                }

                div(class: "nav-logo-arrows-container") {
                    img(alt: "", class: "footer-logo-arrow", height: "30", loading: "lazy", src: "/images/arrow-up-swift-talks.png")
                    img(alt: "", class: "footer-logo-arrow", height: "30", loading: "lazy", src: "/images/arrow-down-swift-talks.png")
                }

            }

            div(class: "body dark footer mobile") {
                "objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development."
            }

        }

        div(class: "footer-sections-container") {

            div(class: "footer-section") {

                h5(class: "h5 dark") {
                    "Learn"
                }

                div(class: "footer-links-container") {

                    a(class: "footer-link dark w--current", href: "/swift-talks", customAttributes: ["aria-current": "page"]) {
                        "Swift Talk"
                    }

                    a(class: "footer-link dark", href: "/books") {
                        "Books"
                    }

                    a(class: "footer-link dark", href: "/workshops") {
                        "Workshops"
                    }

                    a(class: "footer-link dark", href: "/issues") {
                        "Issues"
                    }

                }

            }

            div(class: "footer-section") {

                h5(class: "h5 dark") {
                    "Connect"
                }

                div(class: "footer-links-container") {

                    a(class: "footer-link dark", href: "/blog") {
                        "Blog"
                    }

                    a(class: "footer-link dark", href: "http://twitter.com/objcio", target: "_blank") {
                        "Twitter"
                    }

                    a(class: "footer-link dark", href: "https://www.youtube.com/@objcio", target: "_blank") {
                        "YouTube"
                    }

                }

            }

            div(class: "footer-section") {

                h5(class: "h5 dark") {
                    "More"
                }

                div(class: "footer-links-container") {

                    a(class: "footer-link dark", href: "/about") {
                        "About"
                    }

                    a(class: "footer-link dark", href: "/mailto:mail@objc.io") {
                        "Email"
                    }

                    a(class: "footer-link dark", href: "#") {
                        "Imprint & Legal"
                    }

                }

            }

        }

        div(class: "footer-sections-container-mobile") {

            div(class: "footer-dropdown dark w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {

                div(class: "footer-dropdown-toggle learn w-dropdown-toggle") {

                    div(class: "h5 mobile dark") {
                        "Learn"
                    }

                    h5(class: "h5 mobile toggle-icon footer dark") {
                        "+"
                    }

                }

                nav(class: "footer-dropdown-list w-dropdown-list") {

                    a(class: "footer-dropdown-link dark w-dropdown-link w--current", href: "/swift-talks", customAttributes: ["aria-current": "page"]) {
                        "Swift Talk"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/books") {
                        "Books"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/workshops") {
                        "Workshops"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/issues") {
                        "Issues"
                    }

                }

            }

            div(class: "footer-dropdown dark w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {

                div(class: "footer-dropdown-toggle connect w-dropdown-toggle") {

                    div(class: "h5 mobile dark") {
                        "Connect"
                    }

                    h5(class: "h5 mobile toggle-icon footer dark") {
                        "+"
                    }

                }

                nav(class: "footer-dropdown-list w-dropdown-list") {

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/blog") {
                        "Blog"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "http://twitter.com/objcio", target: "_blank") {
                        "Twitter"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "http://youtube.com/@objcio", target: "_blank") {
                        "YouTube"
                    }

                }

            }

            div(class: "footer-dropdown dark w-dropdown", customAttributes: ["data-hover": "false", "data-delay": "0"]) {

                div(class: "footer-dropdown-toggle more w-dropdown-toggle") {

                    div(class: "h5 mobile dark") {
                        "More"
                    }

                    h5(class: "h5 mobile toggle-icon footer dark") {
                        "+"
                    }

                }

                nav(class: "footer-dropdown-list w-dropdown-list") {

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "#") {
                        "About"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/mailto:mail@objc.io") {
                        "Email"
                    }

                    a(class: "footer-dropdown-link dark w-dropdown-link", href: "/imprint-legal") {
                        "Imprint & Legal"
                    }

                }

            }

        }

    }

    div(class: "footer-dark-html-embed w-embed w-script") {

        script() {

#"""

var Webflow = Webflow || [];
Webflow.push(function () {
var learnDropdownToggle = document.querySelector('.footer-dropdown-toggle.learn');
var learnOpenImage = document.querySelector('.dropdown-open-image.learn');
var learnClosedImage = document.querySelector('.dropdown-closed-image.learn');
var connectDropdownToggle = document.querySelector('.footer-dropdown-toggle.connect');
var connectOpenImage = document.querySelector('.dropdown-open-image.connect');
var connectClosedImage = document.querySelector('.dropdown-closed-image.connect');
var moreDropdownToggle = document.querySelector('.footer-dropdown-toggle.more');
var moreOpenImage = document.querySelector('.dropdown-open-image.more');
var moreClosedImage = document.querySelector('.dropdown-closed-image.more');
learnDropdownToggle.addEventListener('click', function() {
const learnOpenImageStyle = getComputedStyle(learnOpenImage);
const learnOpenImageDisplay = learnOpenImageStyle.display;
if (learnOpenImageDisplay === 'block') {
learnOpenImage.style.display = 'none';
learnClosedImage.style.display = 'block';
} else if (learnOpenImageDisplay === 'none') {
learnOpenImage.style.display = 'block';
learnClosedImage.style.display = 'none';
}
connectClosedImage.style.display = 'block';
connectOpenImage.style.display = 'none';
moreClosedImage.style.display = 'block';
moreOpenImage.style.display = 'none';
});
connectDropdownToggle.addEventListener('click', function() {
const connectOpenImageStyle = getComputedStyle(connectOpenImage);
const connectOpenImageDisplay = connectOpenImageStyle.display;
if (connectOpenImageDisplay === 'block') {
connectOpenImage.style.display = 'none';
connectClosedImage.style.display = 'block';
} else if (connectOpenImageDisplay === 'none') {
connectOpenImage.style.display = 'block';
connectClosedImage.style.display = 'none';
}
learnClosedImage.style.display = 'block';
learnOpenImage.style.display = 'none';
moreClosedImage.style.display = 'block';
moreOpenImage.style.display = 'none';
});
moreDropdownToggle.addEventListener('click', function() {
const moreOpenImageStyle = getComputedStyle(moreOpenImage);
const moreOpenImageDisplay = moreOpenImageStyle.display;
if (moreOpenImageDisplay === 'block') {
moreOpenImage.style.display = 'none';
moreClosedImage.style.display = 'block';
} else if (moreOpenImageDisplay === 'none') {
moreOpenImage.style.display = 'block';
moreClosedImage.style.display = 'none';
}
connectClosedImage.style.display = 'block';
connectOpenImage.style.display = 'none';
learnClosedImage.style.display = 'block';
learnOpenImage.style.display = 'none';
});
});

"""#
        }

    }

    
    script(crossorigin: "anonymous", integrity: "sha256-9/aliU8dGd2tb6OSsuzixeV4y/faTqgFtohetphbbj0=", src: "https://d3e54v103j8qbb.cloudfront.net/js/jquery-3.5.1.min.dc5e7f18c8.js?site=63d78ac5cdfd660fee2a79da", type: "text/javascript")

    script(src: "/js/webflow.js", type: "text/javascript")

}.asOldNode
