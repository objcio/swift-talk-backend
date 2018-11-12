require('./objcjs/index.js');
require('./app-components.js');

// plugins
// todo: require('underscore/underscore');
window.$ = window.jQuery = require('jquery');
require('jquery.kinetic/jquery.kinetic');

window.reframe = require('reframe.js');
window.Cookie  = require('js-cookie');


require('jquery-ujs');
require('jquery-touch-events')();
