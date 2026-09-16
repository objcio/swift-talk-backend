# Public Swift Talk archive

A standalone Swift static-site generator. It reads the existing JSON metadata and Markdown transcripts, then writes HTML, CSS, JavaScript, RSS, and public JSON into `_site/`. There is no application server, database, account system, billing integration, or API credential at build time or runtime. Vimeo serves the videos; the site embeds the full video IDs.

The original backend remains available in the root Swift package during migration. This package does not link to it or load its environment.

## Build and preview

Requires Swift 5.9 or newer with SourceKit available in the toolchain, and Node.js/npm to install and run the pinned Pagefind binary. The first Swift build resolves pinned CommonMark and SourceKitten dependencies. After dependencies are installed, page generation and search indexing are offline.

Run from the repository root, using local checkouts of `objcio/swift-talk-static-data` and `objcio/episode-transcripts`:

```sh
npm ci --prefix StaticSite

swift run --package-path StaticSite swift-talk-static \
  --data /path/to/swift-talk-static-data \
  --transcripts /path/to/episode-transcripts

python3 StaticSite/verify.py _site
python3 -m http.server 8766 --bind 127.0.0.1 --directory _site
```

Open [the local preview](http://127.0.0.1:8766). Browse via HTTP so root-relative asset paths work.

On Chris’s machine the two content checkouts are currently `/Users/chris/objc.io/swift-talk-static-data` and `/Users/chris/objc.io/episode-transcripts`. Content is read directly from those checkouts; fetch their latest revisions before preparing a release.

Options:

| Option | Default | Purpose |
| --- | --- | --- |
| `--data` | Required | `episodes.json`, `collections.json`, `collaborators.json` |
| `--transcripts` | Required | `episode1.md`, `episode2.md`, etc. |
| `--output` | `_site` | Generated files; must be a new or previously generated directory |
| `--assets` | `assets` | Existing fonts, collection artwork, logo, and favicon |
| `--site-assets` | `StaticSite/Assets` | Static-site CSS and JavaScript |
| `--base-url` | `https://talk.objc.io` | Origin for canonical URLs, RSS, and sitemap; root hosting only |
| `--as-of` | Current time | Release cutoff, e.g. `2026-09-15T00:00:00Z` |
| `--pagefind` | `StaticSite/node_modules/.bin/pagefind` | Pagefind executable; a standalone binary can also be supplied |

## Content and output

- All released episodes are public regardless of the old `subscription_only` field. Scheduled episodes remain excluded until their release date. Rebuild to publish them.
- Every released episode must have a nonempty transcript; missing transcripts fail the build. Orphan transcripts without episode metadata are excluded.
- Episodes retain their current `/episodes/S01E<number>-<title-slug>` URLs. Short numeric URLs, zero-padded early episodes, and old title slugs found in the content receive redirect pages. Redirects preserve `?t=` timestamps and hashes with JavaScript.
- The original site’s layouts, typography, artwork, and compiled stylesheet are reused. `static-site.css` adds search controls and accessibility/responsive fixes.
- Transcript text and Swift syntax highlighting are rendered at build time using SourceKit. Highlighting needs no browser JavaScript. Raw editorial HTML is preserved, including existing diagram images. Treat the input repositories as trusted authored content.
- Episode lists, collection pages, transcripts, resources, and Vimeo iframes work without JavaScript. JavaScript adds full-text search and timestamp seeking. Search queries are shareable in the URL.
- Vimeo’s [Player SDK](https://github.com/vimeo/player.js) handles seeking without reloading the video. No progress is sent to a backend. Numeric `#seconds` links and existing `?t=seconds` links are supported.
- `/transcripts/episode<number>.md` offers the original Markdown for download. Historical copy, external links, and external transcript images remain as authored.
- `/episodes.rss`, `/sitemap.xml`, `/robots.txt`, and `/404.html` are generated. `/sitemap` redirects to the XML sitemap.
- `/episodes.json` and `/collections.json` are new public exports, **not** the former authenticated mobile API schema. Account, download-credit, preview-video, and session data are never exported.
- Builds happen in a staging directory and replace the previous output only after all pages, assets, and the Pagefind index are written. An indexing failure preserves the previous site. Rebuilding removes stale generated pages. The generator refuses to overwrite an unmarked directory or overlap an input directory.

## Search

[Pagefind](https://pagefind.app/) indexes only canonical episode titles, synopses, updates, and transcripts (including code). Navigation, collection sidebars, related episodes, archive listings, and redirect pages are excluded. Title and heading matches are weighted above body text; synopses receive a smaller boost. Episode numbers and collection names are searchable metadata, and collection IDs provide filters.

The custom results interface uses the original site's typography and colors. It loads Pagefind on search focus, fetches index chunks as needed, and loads ten results at a time. An empty query shows the original newest-first episode grid; a query shows ranked results and highlighted excerpts. Quoted phrases are supported. This is keyword search with Pagefind's stemming and prefix matching, not semantic search or automatic typo correction.

Transcript timestamps have stable anchors such as `#t-65`. Search maps Pagefind's matching word locations to those anchors and links to `?t=65#t-65` to scroll to the passage and seek the video. Each compact result shows one short matching passage, with a second available through a disclosure. Title/metadata matches without timed passages show the episode synopsis. Duplicate timestamps receive unique anchor suffixes. Stale asynchronous responses are discarded when the query changes; load failures leave the episode browser available.

The CLI always builds the index. Programmatic `BuildConfiguration` callers can omit `pagefind` to generate only HTML, as the Swift unit-test fixtures do.

## Verification

```sh
swift test --package-path StaticSite
npm test --prefix StaticSite
python3 StaticSite/verify.py _site
node --check StaticSite/Assets/static-site.js
```

Tests cover formerly paid episodes, full transcripts and Vimeo IDs, release filtering, timestamps, syntax highlighting with exact code/Unicode preservation, URL aliases, output isolation, safe rebuilds, Vimeo privacy hashes, indexing failure, and search passage boundaries/escaping. The verifier scans all generated HTML and stylesheets for local links and assets, confirms each exported episode has its transcript and player, and parses RSS and sitemap XML.

## Publishing and remaining migration work

Publish only the contents of `_site/`, including `pagefind/`, to a static host. Configure directory indexes (`/episodes/...` → `/episodes/.../index.html`), `404.html` for missing pages, and standard MIME types for HTML, CSS, JavaScript, WebAssembly, JSON, RSS, SVG, fonts, and Markdown. Deploy each build together so the HTML and index stay in sync. Do not deploy the repository root or the original backend Dockerfile. Hosting and DNS cutover are not configured yet.

Vimeo privacy and embedding permissions must allow the final domain. Public HTML cannot override Vimeo restrictions. If a video is unlisted and requires a privacy hash, add `vimeo_hash` to that episode’s metadata; it is included in the embed URL. No video-download links or expiring Vimeo API URLs are generated.

Before switching production, reconcile the latest content checkouts, verify formerly paid video playback on the final domain, and migrate any additional historical redirects available from production. Known content links are covered; the former server accepted arbitrary stale title suffixes by episode number, which requires a host redirect rule or a broader alias list to reproduce fully. Retiring subscriptions and backend infrastructure is a separate operational step.
