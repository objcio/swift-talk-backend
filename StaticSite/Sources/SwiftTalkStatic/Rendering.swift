import Foundation

extension Renderer {
    var home: String {
        let episodes = content.episodes
        let recent = episodes.dropFirst().prefix(4).map { "<div class=\"mb++ s+|col s+|width-1/2\">\(card($0, synopsis: false))</div>" }.joined()
        let collections = content.collections.map { "<li class=\"col width-full s+|width-1/2 l+|width-1/3 mb++\">\(collectionCard($0))</li>" }.joined()
        return page(title: "Swift Talk", path: "/", description: "A video series on Swift programming by Chris Eidhof and Florian Kugler. Every episode and transcript is freely available.", body: """
        <header class="bgcolor-blue pattern-shade"><div class="container">
          <h1 class="color-white bold ms4">Swift Talk</h1>
          <p class="mt--"><a class="label smallcaps color-blue-darkest bgcolor-orange no-decoration" href="https://www.objc.io/blog/2026/09/04/the-end-of-swift-talk">Archive Mode</a></p>
          <p class="ms2 color-darken-50 lh-110 mw7 mt-">A video series on Swift programming.</p>
        </div></header>
        <section class="container"><header class="mb+"><h2 class="inline-block bold color-black">Recent Episodes</h2><a class="inline-block ms-1 ml- color-blue no-decoration hover-underline" href="/episodes">See All</a></header>
          <div class="m-cols flex flex-wrap"><div class="mb++ p-col width-full l+|width-1/2">\(card(episodes[0], featured: true))</div><div class="p-col width-full l+|width-1/2"><div class="s+|cols s+|cols--2n">\(recent)</div></div></div>
        </section>
        <section class="container"><header class="mb+"><h2 class="inline-block bold lh-100 mb---">Collections</h2><a class="inline-block ms-1 ml- color-blue no-decoration hover-underline" href="/collections">Show Contents</a><p class="lh-125 color-gray-60">Browse all Swift Talk episodes by topic.</p></header>
          <ul class="cols s+|cols--2n l+|cols--3n">\(collections)</ul>
        </section>
        """, image: episodes[0].posterURL)
    }

    var episodesPage: String {
        let items = content.episodes.map { episode in
            let search = ([String(episode.number), content.fullTitle(episode), episode.synopsis] + content.collections(for: episode).map(\.title)).joined(separator: " ")
            return "<li class=\"col mb++ width-full s+|width-1/2 m+|width-1/3 xl+|width-1/4\" data-episode data-search=\"\(search.escaped)\" data-collections=\"\(episode.collections.joined(separator: " ").escaped)\">\(card(episode))</li>"
        }.joined()
        let options = content.collections.map { "<option value=\"\($0.id.escaped)\">\($0.title.escaped)</option>" }.joined()
        return page(title: "All Episodes", path: "/episodes", description: "Browse every Swift Talk video and transcript, freely available.", body: """
        \(pageHeader("All Episodes"))
        <section class="container pb0" aria-label="Episode archive">
          <h2 class="bold lh-100 mb+ result-count" aria-live="polite" aria-atomic="true">\(content.episodes.count) Episodes</h2>
          <form class="search-form static-search mb++" role="search" hidden>
            <div class="static-search-field"><label class="block smallcaps color-gray-40 mb--" for="search">Search episodes</label><input id="search" type="search" name="q" placeholder="SwiftUI, networking, episode number…" autocomplete="off"></div>
            <div><label class="block smallcaps color-gray-40 mb--" for="collection">Collection</label><select id="collection" name="collection"><option value="">All collections</option>\(options)</select></div>
            <button class="reset-button color-blue" type="reset">Clear</button>
          </form>
          <p class="no-results color-gray-40 lh-135 mb++" hidden>No episodes found. Try another search or collection.</p>
          <ul class="cols static-episode-list">\(items)</ul>
        </section>
        """)
    }

    var collectionsPage: String {
        let items = content.collections.map { "<li class=\"col width-full s+|width-1/2 l+|width-1/3 mb++\">\(collectionCard($0, showEpisodes: true))</li>" }.joined()
        return page(title: "All Collections", path: "/collections", description: "Explore Swift Talk by topic, from SwiftUI to functional programming.", body: """
        \(pageHeader("All Collections"))<div class="container pb0"><h2 class="bold lh-100 mb+">\(content.collections.count) Collections</h2><ul class="cols s+|cols--2n l+|cols--3n">\(items)</ul></div>
        """)
    }

    func collectionPage(_ collection: Collection) -> String {
        let episodes = content.episodes(in: collection)
        let image = "images/collections/\(collection.title)@4x.png"
        let background = FileManager.default.fileExists(atPath: assets.appendingPathComponent(image).path)
            ? "background-image:url('\(URL(string: "/assets/" + image)!.absoluteString.escaped)')" : ""
        let items = episodes.enumerated().map { index, episode in
            "<li class=\"flex justify-center mb++ m+|mb+++\"><div class=\"width-1 ms1 mr- color-theme-highlight bold lh-110 m-|hide\">\(collection.useAsTitlePrefix ? "\(index + 1)." : "→")</div>\(card(episode, wide: true, showCollection: false))</li>"
        }.joined()
        return page(title: collection.title, path: collection.path, description: collection.description, body: """
        <div class="pattern-illustration overflow-hidden" style="\(background)"><div class="wrapper"><header class="offset-content offset-header pv++ bgcolor-white">
          <p class="ms1 color-gray-70 links clearfix"><a class="bold" href="/">Swift Talk</a>&#8202; <a href="/collections">Collection</a></p>
          <h1 class="ms5 bold color-black mt--- lh-110 mb-">\(collection.title.escaped)</h1><p class="ms1 color-gray-40 text-wrapper lh-135">\(collection.description.escaped)</p>
          <p class="color-gray-65 lh-125 mt">\(episodes.count) Episodes<span class="ph---">·</span>\(hoursAndMinutes(episodes.reduce(0) { $0 + $1.mediaDuration }))</p>
        </header></div></div>
        <div class="wrapper pt++"><ul class="offset-content">\(items)</ul></div>
        """, theme: "collection")
    }

    func episodePage(_ episode: Episode, transcript: Transcript) -> String {
        let title = content.fullTitle(episode)
        let chapters = transcript.chapters.map {
            "<li class=\"border-bottom border-1 border-color-lighten-10\"><a class=\"flex color-inherit pv items-baseline no-decoration hover-cascade\" data-time=\"\($0.seconds)\" href=\"?t=\($0.seconds)#video\"><span class=\"hover-cascade__underline\">\($0.title.escaped)</span><span class=\"ml-auto color-orange pl-\">\(timestamp($0.seconds))</span></a></li>"
        }.joined()
        let resources = episode.resources.map {
            "<li class=\"flex\"><div class=\"flex-none mr-\"><a class=\"block bgcolor-orange radius-5 hover-bgcolor-blue\" href=\"\($0.url.escaped)\" aria-label=\"\($0.title.escaped)\">\(svg("icon-resource-code.svg", classes: "block icon-40"))</a></div><div class=\"ms-1 lh-125\"><h3 class=\"mb---\"><a class=\"bold color-black hover-underline no-decoration\" href=\"\($0.url.escaped)\">\($0.title.escaped)</a></h3><p class=\"color-gray-50\">\($0.subtitle.escaped)</p></div></li>"
        }.joined()
        let collection = content.collections(for: episode).first.map { "<section class=\"pb++\"><h2 class=\"color-blue mb smallcaps\">In Collection</h2>\(collectionCard($0, showEpisodes: true))<p class=\"ms-1 mt text-right\"><a class=\"no-decoration color-blue hover-underline\" href=\"/collections\">See All Collections →</a></p></section>" } ?? ""
        let collaborators = episode.collaborators.compactMap { id in content.collaborators.first { $0.id == id } }.map {
            "<li><dl class=\"flex justify-between\"><dt class=\"color-gray-60\">\($0.roleName.escaped)</dt><dd class=\"color-gray-15 text-right\"><a class=\"color-gray-15 hover-underline no-decoration\" href=\"\($0.url.escaped)\">\($0.name.escaped)</a></dd></dl></li>"
        }.joined()
        let updates = (episode.updates ?? []).map {
            "<aside class=\"border border-1 border-color-subtle-blue bgcolor-pale-blue pa radius-5 mb+\"><h2 class=\"smallcaps color-blue-darker mb-\">Update · \(formattedDate($0.date))</h2><div class=\"c-text ms-1\">\(markdown($0.text))</div></aside>"
        }.joined()
        let recent = content.episodes.filter { $0.number != episode.number }.prefix(8).map { "<div class=\"flex-110 pr+ min-width-5\">\(card($0, synopsis: false))</div>" }.joined()
        return page(title: title, path: episode.path, description: episode.synopsis, body: """
        <div class="js-episode">
          <div class="bgcolor-night-blue pattern-shade-darker"><div class="container l+|pb0 l+|n-mb++">
            <header class="mb++ pb"><p class="color-orange ms1"><a class="color-inherit no-decoration bold hover-underline" href="/">Swift Talk</a> # \(String(format: "%02d", episode.number))</p><h1 class="ms5 color-white bold mt-- lh-110">\(title.escaped)</h1></header>
            <div class="l+|flex static-watch"><div class="flex-110 order-2 static-player-column"><div id="video" class="ratio ratio--16/9"><div class="ratio__container"><iframe id="vimeo-player" class="static-video" src="\(episode.embedURL.escaped)" title="\(title.escaped) — full episode" width="1280" height="720" allow="autoplay; fullscreen; picture-in-picture; encrypted-media" allowfullscreen></iframe></div></div></div>
              <aside class="min-width-5 relative order-1 mt++ l+|mt0 l+|mr++ l+|mb++" aria-label="Video chapters"><div class="l+|absolute l+|position-stretch stretch width-full flex flex-column">
                <h2 class="color-blue border-top border-2 pt mb+ flex-none flex items-baseline"><span class="smallcaps">In this episode</span><span class="ml-auto ms-1 bold">\(timestamp(Int(episode.mediaDuration)))</span></h2>
                <div class="flex-auto overflow-auto border-color-lighten-10 border-1 border-top"><ol class="lh-125 ms-1 color-white">\(chapters)</ol></div>
              </div></aside>
            </div>
          </div></div>
          <div class="bgcolor-white l+|pt++"><div class="container">
            <p id="player-status" class="color-gray-40 lh-135 mb+" role="status" hidden></p>
            <div class="l+|flex l-|stack+++ m-cols">
              <article class="p-col l+|flex-auto l+|width-2/3 xl+|width-7/10 static-transcript-column"><div class="text-wrapper"><div class="lh-140 color-blue-darkest ms1 bold mb+">\(markdown(episode.synopsis))</div></div>\(updates)
                <section id="transcript" aria-label="Transcript"><div class="js-transcript"><div class="transcript c-text c-text--fit-code">\(transcript.html)</div></div></section>
                <p class="mt+ ms-1"><a class="color-blue no-decoration hover-underline" href="/transcripts/episode\(episode.number).md" download>Download Transcript as Markdown ↓</a></p>
              </article>
              <aside class="p-col max-width-7 center stack l+|width-1/3 xl+|width-3/10 l+|flex-auto static-sidebar">
                \(resources.isEmpty ? "" : "<section class=\"pb++\"><h2 class=\"color-blue mb smallcaps\">Resources</h2><ul class=\"stack\">\(resources)</ul></section>")
                \(collection)
                <section class="pb++"><h2 class="color-blue mb smallcaps">Episode Details</h2><ul class="ms-1 stack"><li><dl class="flex justify-between\"><dt class="color-gray-60">Released</dt><dd class="color-gray-15 text-right">\(formattedDate(episode.releaseAt))</dd></dl></li>\(collaborators)</ul></section>
              </aside>
            </div>
          </div></div>
        </div>
        <aside class="bgcolor-pale-gray pt++"><header class="container-h flex items-center justify-between"><div><h2 class="inline-block bold color-black">Recent Episodes</h2><a class="inline-block ms-1 ml- color-blue no-decoration hover-underline" href="/episodes">See All</a></div></header><div class="flex scroller p-edges pt pb++"><div class="scroller__offset flex-none"></div>\(recent)</div></aside>
        """, image: episode.posterURL, player: true)
    }
}
