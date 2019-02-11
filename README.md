# Swift Talk Backend

This is the source code of the Swift Talk backend: [https://talk.objc.io](https://talk.objc.io)

While we abstracted non-app-specific parts away into frameworks, this is not a web framework. Here's a minimal description of the structure:

## SwiftTalkServerLib

This framework contains the application-specific code. There are a few main parts to it:

- The *routes* define the available endpoints and transform URLs to routes and routes to URLs
- The *interpret* methods contain the application logic for each route
- The *views* contain rendering logic
- The *queries* abstract away the database (but only a little bit)
- The *third-party services* communicate with JSON and XML APIs of third-party providers

### Interpreting

For testability (and because we wanted to experiment), we wrote our route interpreter using the [final-tagless](https://talk.objc.io/episodes/S01E89-extensible-libraries-2-protocol-composition) style. This allows us to write a normal interpreter that does the usual web-server things: execute database queries, perform network requests, etc. It also allows us to have a [test interpreter](https://github.com/objcio/video-swift-backend/blob/master/Tests/swifttalkTests/TestHelpers.swift), so that we can write high-level flow tests (with [easy network tests](https://talk.objc.io/episodes/S01E137-testing-networking-code)).

### Database

We use PostgreSQL and write standard SQL queries to access the database. We represent each table with a struct and use Codable to help generate simple queries and to parse the results from PostgreSQL back into struct values ([Episode #114](https://talk.objc.io/episodes/S01E114-reflection-with-mirror-and-decodable)).

### Third-Party Services

Rather than depending on third-party frameworks, we decided to write our own wrappers around the REST endpoints of third-party services (e.g. GitHub, Recurly, Sendgrid, Vimeo) using our [tiny networking](https://talk.objc.io/episodes/S01E133-tiny-networking-library-revisited) library.

## HTML

The HTML framework defines an enum to represent HTML/XML nodes. There is one special feature: a `Node` is generic over some read-only state. This allows us to pass around "global" state like a CSRF token and session/user data without actually making that global, and without having to explicitly pass it around everywhere.

For an example, see [HTMLExtensions.swift](https://github.com/objcio/video-swift-backend/blob/master/Sources/SwiftTalkServerLib/Views/HTMLExtensions.swift). We add multiple extension to our `Node` type when the read-only state is of type `STRequestEnvironment`.

## Routing

For routing, we use a [`Router` struct](https://github.com/objcio/video-swift-backend/blob/master/Sources/Routing/Routing.swift#L49) that captures both *parsing* and *generating* a route in one. [Our routes](https://github.com/objcio/video-swift-backend/blob/master/Sources/SwiftTalkServerLib/Routes.swift#L13) are defined as enums, and using the `Router` we can write one description that converts the case into a URL and parses a URL, without having too worry too much about keeping them in sync.

We also use the enum cases to generate links, making sure that every link is well-formed and has all the necessary parameters. 

## Incremental

We use our [Incremental programming library](https://talk.objc.io/collections/incremental-programming) to transform and cache static data. For example, when the markdown file for an episode is changed, we recompute the highlighted version (highlighting is done using a `SourceKitten` wrapper). Because this can take a little while, the results are cached.

## NIOWrapper

This framework is a lightweight wrapper around SwiftNIO, which contains a few primitives to write data, send redirects, process POST data, etc. The wrapper depends only minimally on NIO, which makes it easy to test without NIO.

## WebServer

The WebServer framework builds on top of the NIOWrapper, providing some higher level abstractions e.g. to write HTML or JSON responses. It also integrates the with the Database and Networking frameworks to provide response APIs to execute queries or call third-party network endpoints.

# Installation Notes

### PostgreSQL

You need PostgreSQL and libpq. To set up a local postgres instance:

```
initdb -D .postgres
chmod 700 .postgres
pg_ctl -D .postgres start
createdb swifttalk_dev
```

### Compiling Assets

Make sure to have browserify installed, then run:

```
npm install -g browserify
```

Then generate the javascript:

```
npm install
browserify assets_source/javascripts/application.js > assets/application.js
```

You can also use `--debug` to include source maps (for better debugging).

To build the stylesheets:

```
./build-css.sh
```

### Deployment

We deploy to a heroku-based docker app (needs postgres as well).

If you get a "basic auth" error: heroku container:login

```swift
heroku container:push web
heroku container:release web
```

### Running in Docker

```
docker run -a stdin -a stdout -i -t --env-file .env --env RDS_HOSTNAME=(ifconfig en1 | awk '/inet /{print $2}') -p 8765:8765 swifttalk-server
```


### Debugging Linux Bugs

You can run a docker container from one of the intermediate steps. Then install screen and vim, and you have a small linux dev environment.

https://medium.com/ihme-tech/troubleshooting-the-docker-build-process-454583c80665
