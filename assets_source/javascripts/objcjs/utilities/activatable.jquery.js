// Activatable
// Toggle .is-active on a container when a descendant control is toggled.
// Tip: combine this with CSS utilities e.g. hide-if-active or show-if-active

(function ($) {

  $(document).on('click', '.js-activatable .js-activatable-toggle', function (event) {
    $(this).closest('.js-activatable').toggleClass('is-active');
    event.preventDefault();
  });

})(jQuery);
