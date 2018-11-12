//= require_tree ./plugins
//= require_tree ./utilities
//= require_tree ./components
//= require_self

window.App = window.App || {};

window.App.touchEventsSupported = function () {
  return (('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch);
}
