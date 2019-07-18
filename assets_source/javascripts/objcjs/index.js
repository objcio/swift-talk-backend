
window.App = window.App || {};

window.App.touchEventsSupported = function () {
  return (('ontouchstart' in window) || window.DocumentTouch && document instanceof DocumentTouch);
}
