(function ($) {

  $(document).on('click', '.js-toggle', function (event) {
    var toggleSelector = $(this).data('toggle');
    var $toggleableElement = $(toggleSelector);
    if ($toggleableElement.length) {
      $(toggleSelector).toggle();
      $(this).toggleClass('is-active');
      event.preventDefault();
    }
  });

})(jQuery);
