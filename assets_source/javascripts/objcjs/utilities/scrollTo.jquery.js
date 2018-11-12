(function ($) {
  $('.js-scrollTo').on('click', "a[href^='#']", function() {
    $.scrollTo($(this).attr('href'));
    return false;
  });
})(jQuery);
