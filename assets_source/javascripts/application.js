window.$ = window.jQuery = require('jquery');

window._ = require('underscore'); // necessary for some of the objcjs plugins...
require('./objcjs/plugins/scrollTo.jquery.js');
require('./objcjs/plugins/_selectText.js');
require('./objcjs/utilities/scrollTo.jquery.js');
require('./objcjs/utilities/expandable.jquery.js');
require('./objcjs/utilities/outbound-links.jquery.js');
require('./objcjs/utilities/closeable.jquery.js');
require('./objcjs/utilities/activatable.jquery.js');
require('./objcjs/utilities/toggle.jquery.js');
require('./objcjs/components/_code-selection.js');
require('./objcjs/components/_scroller.js');
require('./objcjs/index.js');

require('./app-components.js');

// plugins
// todo: require('underscore/underscore');
require('jquery.kinetic/jquery.kinetic');

window.reframe = require('reframe.js');
window.Cookie  = require('js-cookie');


require('jquery-ujs');
require('jquery-touch-events')();
