//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1
import HTML


@NodeBuilder
func newHomeBody() -> Swim.Node {
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

                div(class: "button-container github") {

                    a(class: "primary-button w-button", href: "#") {
                        "Sign in with GitHub"
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

    }

    div(class: "footer dark") {

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

    }

    script(crossorigin: "anonymous", integrity: "sha256-9/aliU8dGd2tb6OSsuzixeV4y/faTqgFtohetphbbj0=", src: "https://d3e54v103j8qbb.cloudfront.net/js/jquery-3.5.1.min.dc5e7f18c8.js?site=63d78ac5cdfd660fee2a79da", type: "text/javascript")

    script(src: "/js/webflow.js", type: "text/javascript")

}


func renderHome(episodes: [EpisodeWithProgress]) -> Node {
    let metaDescription = "A weekly video series on Swift programming by Chris Eidhof and Florian Kugler. objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development."
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming.", extraClasses: "ms4"))
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
    var bodyStr = ""
    newHomeBody().write(to: &bodyStr)
    return LayoutConfig(contents: [header, .raw(bodyStr) /*projectsView, recentEpisodes, collections*/], description: metaDescription).layout
}

