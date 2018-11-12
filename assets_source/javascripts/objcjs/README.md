# objcjs

This holds shared JS between the main [objc.io](https://www.objc.io) website and the [Swift Talk](https://talk.objc.io) website.

There are some dependencies that need to be installed in each project, though:

* https://github.com/js-cookie/js-cookie
* underscore.js
* jquery.kinetic

In the future, would be better to move the shared code to a NPM-hosted module, so dependencies could be declared there, but that would require switching to Browserify on the main website project.
