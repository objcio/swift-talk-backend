// DEPENDENCIES:
// * https://github.com/js-cookie/js-cookie

// Closeable
// Closes a .js-closeable container when a .js-closeable-toggle is clicked. [1]
// Optionally, sets a cookie when closing. [2]
(function ($) {

  $(document).on('click', '.js-closeable .js-closeable-toggle', function (event) {
    var $container = $(this).closest('.js-closeable');
    if (!$container.length)
      return;
    // [1]
    $container.remove();
    event.preventDefault();

    // [2]
    if (cookie_name = $container.data('closeable-cookie') && window.Cookie)
      Cookie.set(cookie_name, Date.now());
  });

})(jQuery);
