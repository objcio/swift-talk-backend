import Foundation

extension Renderer {
    func card(_ episode: Episode, featured: Bool = false, wide: Bool = false, synopsis: Bool = true, showCollection: Bool = true) -> String {
        let classes = "episode-card flex flex-column width-full " + (wide ? "max-width-6 m+|max-width-none m+|flex-row " : "") + (featured ? "min-height-full hover-scale transition-all transition-transform" : "")
        let pictureClasses = wide ? "flex-auto mb- m+|width-1/3 m+|order-2 m+|mb0 m+|pl++" : "flex-none"
        let pictureLinkClasses = "block ratio overflow-hidden " + (featured ? "ratio--2/1 radius-5 no-radius-bottom" : "ratio--22/10 radius-3 hover-scale transition-all transition-transform")
        let image = episode.posterURL(width: featured ? 1260 : 590, height: featured ? 630 : 270).map {
            "<img class=\"static-poster-image\" src=\"\($0.escaped)\" alt=\"\" loading=\"\(featured ? "eager" : "lazy")\">"
        } ?? "<span class=\"static-poster-placeholder\">Swift Talk</span>"
        let collection = showCollection ? content.collections(for: episode).first : nil
        let collectionLink = collection.map { "<a class=\"inline-block no-decoration color-blue hover-underline mb-- \(featured ? "" : "ms-1")\" href=\"\($0.path.escaped)\">\($0.title.escaped)</a>" } ?? ""
        let contentClasses = "flex-auto flex flex-column " + (wide ? "m+|width-2/3" : "justify-center") + (!featured && !wide ? " pt-" : "") + (featured ? " pa bgcolor-pale-gray radius-5 no-radius-top" : "")
        let titleClasses = "block lh-110 no-decoration bold color-black hover-underline " + (wide ? "ms1" : (featured ? "ms2" : ""))
        let smallIcon = featured ? "" : svg("icon-play.svg", classes: "svg-fill-current icon-26")
        let bigIcon = featured ? "<span class=\"absolute position-stretch flex justify-center items-center color-white\">\(svg("icon-play.svg", classes: "svg-fill-current icon-46"))</span>" : ""
        return """
        <article class="\(classes)">
          <div class="\(pictureClasses)"><a class="\(pictureLinkClasses)" href="\(episode.path.escaped)" aria-label="Watch \(content.fullTitle(episode).escaped)">
            <div class="ratio__container bg-center bg-cover">\(image)</div><div class="absolute position-stretch opacity-60 blend-darken gradient-episode-black"></div>
            <div class="absolute position-stretch flex flex-column"><div class="mt-auto width-full flex items-center lh-100 ms-1 pa- color-white">\(smallIcon)<span class="ml-auto bold text-shadow-20">\(Int((episode.mediaDuration / 60).rounded())) min</span></div></div>\(bigIcon)
          </a></div>
          <div class="\(contentClasses)"><header>\(collectionLink)<h3><a class="\(titleClasses)" href="\(episode.path.escaped)">\(episode.title.escaped)</a></h3></header>
            \(synopsis ? "<p class=\"lh-135 color-gray-40 mv-- text-wrapper \(!featured && !wide ? "ms-1 hyphens" : "")\">\(episode.synopsis.escaped)</p>" : "")
            <p class="color-gray-65 \(!featured && !wide ? "mt-- ms-1" : "")">Episode \(episode.number)<span class="ph---">·</span><time datetime="\(formattedDate(episode.releaseAt, format: "yyyy-MM-dd"))">\(formattedDate(episode.releaseAt, format: "MMM dd yyyy"))</time></p>
          </div>
        </article>
        """
    }

    func collectionCard(_ collection: Collection, showEpisodes: Bool = false) -> String {
        let path = "images/collections/\(collection.title).svg"
        let image = FileManager.default.fileExists(atPath: assets.appendingPathComponent(path).path)
            ? "<img class=\"block width-full height-auto\" src=\"\(URL(string: "/assets/" + path)!.absoluteString.escaped)\" alt=\"\" loading=\"lazy\">"
            : "<span class=\"static-collection-placeholder\" aria-hidden=\"true\">{ }</span>"
        let episodes = content.episodes(in: collection)
        let list = showEpisodes ? "<ul class=\"mt-\">" + episodes.map { episode in
            let primary = content.collections(for: episode).first
            let title = primary.map { $0.id == collection.id ? episode.title : "\($0.title): \(episode.title)" } ?? episode.title
            return "<li class=\"flex items-baseline justify-between ms-1 line-125\"><span class=\"nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45\"><a class=\"no-decoration color-inherit hover-underline\" href=\"\(episode.path.escaped)\">\(title.escaped)</a></span><span class=\"flex-none pl- pv- color-gray-70\">\(timestamp(Int(episode.mediaDuration)))</span></li>"
        }.joined() + "</ul>" : ""
        return """
        <article class="collection-card"><a href="\(collection.path.escaped)" aria-label="\(collection.title.escaped)"><figure class="mb-" style="background-color:#F2F4F2">\(image)</figure></a>
          <div class="flex items-center pt--"><h3><a class="inline-block lh-110 no-decoration bold color-black hover-underline" href="\(collection.path.escaped)">\(collection.title.escaped)</a></h3></div>
          <p class="ms-1 color-gray-55 lh-125 mt--">\(episodes.count) Episodes<span class="ph---">·</span>\(hoursAndMinutes(episodes.reduce(0) { $0 + $1.mediaDuration }))</p>\(list)
        </article>
        """
    }
}
