# video-swift-backend

This is the source code of the Swift Talk backend: https://talk.objc.io/.

While we abstracted non-app-specific parts away into frameworks, this is not a web framework. Here's a minimal description of the structure:

## *SwiftTalkServerLib*

This framework contains the application-specific code. There are three main parts:

- The *interpret* methods contain application logic
- The *views* contain rendering logic
- The *queries* abstract away the database (but only a little bit)

### Interpreting

For testability (and because we wanted to experiment), we wrote our interpreter using [final-tagless](https://talk.objc.io/episodes/S01E89-extensible-libraries-2-protocol-composition) style. This allows us to write a normal interpreter that executes database queries, performs network requests, and does web-server things. It also allows us to have a [test interpreter](https://github.com/objcio/video-swift-backend/blob/master/Tests/swifttalkTests/TestHelpers.swift), so that we can write high-level flow tests (with [easy network tests](https://talk.objc.io/episodes/S01E137-testing-networking-code)).

### Database

We use Postgres, and for "boring" queries, we generate the SQL and parsing using Codable ([Episode #114](https://talk.objc.io/episodes/S01E114-reflection-with-mirror-and-decodable)).

### Third-Party Services

Rather than depending on third-party frameworks, we decided to write our own wrappers around their REST endpoints using our [tiny networking](https://talk.objc.io/episodes/S01E133-tiny-networking-library-revisited) library.

## HTML

To represent HTML/XML, we have an enum for the different node types. There is one special feature: a `Node` is generic over some read-only state. This allows us to pass around "global" state like a CSRF token and session/user data without actually making that global, and without having to explicitly pass it around everywhere.


For an example, see [HTMLExtensions.swift](https://github.com/objcio/video-swift-backend/blob/master/Sources/SwiftTalkServerLib/Views/HTMLExtensions.swift). We add multiple extension to our `Node` type when the read-only state is of type `STRequestEnvironment`.

## Routing

For routing, we use a [`Router` struct](https://github.com/objcio/video-swift-backend/blob/master/Sources/Routing/Routing.swift#L49) that captures both *parsing* and *generating* a route in one. [Our routes](https://github.com/objcio/video-swift-backend/blob/master/Sources/SwiftTalkServerLib/Routes.swift#L13) are defined as enums, and using the `Router` we can write one description that converts the case into a URL and parses a URL, without having too worry too much about keeping them in sync.

We also use the enum cases to generate links, making sure that every link is well-formed and has all the necessary parameters. 

## Incremental

We use our [Incremental programming library](https://talk.objc.io/collections/incremental-programming) to transform and cache static data. For example, when the markdown file for an episode is changed, we recompute the highlighted version (highlighting is done using a `SourceKitten` wrapper). Because this can take a little while, the results are cached.

## WebServer

We use a wrapper around SwiftNIO as our backend. The wrapper depends only minimally on NIO, which makes it easy to test without NIO.

# Notes

## Postgres

To set up a local postgres instance, do:

```
initdb -D .postgres
chmod 700 .postgres
pg_ctl -D .postgres start
createdb swifttalk_dev
```

Make sure to have `libpq` installed as well.

## Compiling Assets

First, make sure to have browserify installed:

```
npm install -g browserify
```

Then generate the javascript:

````
npm install
browserify assets_source/javascripts/application.js > assets/application.js
```

You can also use `--debug` to include source maps (for better debugging).

To build the stylesheets:

```
./build-css.sh
```

## Deployment

A heroku-based docker app (needs postgres as well).

If you get a "basic auth" error: heroku container:login

```swift
heroku container:push web
heroku container:release web
```

## Running in Docker

```
docker run -a stdin -a stdout -i -t --env-file .env --env RDS_HOSTNAME=(ifconfig en1 | awk '/inet /{print $2}') -p 8765:8765 swifttalk-server
```


## Debugging Linux Bugs

You can run a docker container from one of the intermediate steps. Then install screen and vim, and you have a small linux dev environment.

https://medium.com/ihme-tech/troubleshooting-the-docker-build-process-454583c80665
