//
// Scroller
//
// This component enhances a native browser horizontall scrolling container with:
// 1. Drag to scroll, to aid scrolling in devices with mouse
// 2. Left/Right arrows, to aid scrolling in devices with mouse
//
// This makes use of Kinetic, a jQuery plugin.
//
// The HTML structure should be:
//
// .js-scroller
//   .js-scroller-buttons
//     .js-scroller-button-left.scroller-button
//     .js-scroller-button-right.scroller-button
//   .js-scroller-container.scroller
//
// Notes:
// * The buttons can be totally omitted.
// * In that case, js-scroller and js-scroller-container can be the same element
//
$(function() {

  $('.js-scroller').each(function () {

    // Root element which contains both buttons and scrolling container
    var $root            = $(this);
    // Scrolling container, which will be scrolled. Can be the same as the container
    var $container       = $root.is('.js-scroller-container') ? $root : $root.find('.js-scroller-container');
    // Button container and individual left/right buttons for aid with scrolling
    var $buttonContainer = $root.find('.js-scroller-buttons');
    var $buttons         = {
      left:       $root.find('.js-scroller-button-left'),
      right:      $root.find('.js-scroller-button-right')
    };



    // Test if the container is scrollable
    var containerIsScrollable = function () {
      var container = $container.get(0);
      return container.scrollWidth > container.clientWidth;
    }



    // Update left/right paging buttons
    var updateButtons = {

      // Check whether we’ve hit a boundary and one of the buttons needs to be disabled
      state: function () {
        var container = $container.get(0);
        var buttonEnabled = {
          left:  container.scrollLeft > 0,
          right: container.clientWidth + container.scrollLeft < container.scrollWidth
        };
        // Enabled/disable buttons
        _.each(buttonEnabled, function(isEnabled, key) {
          $buttons[key].attr('disabled', isEnabled ? null : 'disabled');
        });
      },

      // Hide or show buttons altogether if container doesn't scroll
      presence: function () {
        $buttonContainer.toggle(containerIsScrollable());
      }
    };



    // Update container with selector if it's unscrollable.
    // This is used to override Kinetic's custom cursor
    var updateScrollability = function() {
      $container.toggleClass('is-unscrollable', !containerIsScrollable())
    }



    // Method to page container with buttons
    var slideContainerTo = function (direction) {
      // Percentage of visible content to be scrolled (0 to 1)
      var SCROLL_PERCENTAGE = 0.95;
      // Speed of scrolling animation
      var SCROLL_SPEED      = 400;

      // Width of the root element is used to calculate how much to scroll
      var width             = $root.outerWidth();
      var scrollAmount      = Math.round(width * SCROLL_PERCENTAGE);
      // Get horizontal scroll position, and use to calculate new one
      var currentScrollLeft = $container.scrollLeft();
      var newScrollLeft     = currentScrollLeft + (direction == 'right' ? scrollAmount : -1*scrollAmount)
      // Animate the scrolling, then check button enabled state
      $container.animate({ scrollLeft: newScrollLeft }, SCROLL_SPEED);
    };



    //
    // SET UP
    //

    // 1. Activate scroller, only on horizontal direction, only if no touch is present
    // (this is because kinetic uses touch events and breaks clicks inside)
    if (!window.App.touchEventsSupported()) {
      $container.kinetic({ y: false });
    }

    // 2. If buttons are present…
    if ($buttonContainer.length) {

      // 2.1. Add button event handlers for paging the container
      _.each($buttons, function($button, key) {
        $button.on('click', function () { slideContainerTo(key); })
      })

      // 2.2. Check need for buttons and their state
      updateButtons.state();
      updateButtons.presence();

      // 2.3. Update buttons
      //      - …fully, on resize or orientation change, as size of container can change
      //      - …just their state, when container is scrolled
      $(window).on('orientationchange resize', _.debounce(function () {
        updateButtons.state();
        updateButtons.presence();
      }, 100));
      $container.on('scroll', _.debounce(updateButtons.state, 100));
    }

    // 3. Update classes to control appearance based on container being scrollable or not
    updateScrollability();
    $(window).on('load orientationchange resize', _.debounce(function () {
      updateScrollability();
    }, 100));

  });

});
