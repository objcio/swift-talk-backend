(function($) {
  var OUTBOUND_DOMAINS = [
    'www.amazon.com',
    'www.amazon.co.uk',
    'www.amazon.de',
    'www.amazon.jp',
    'www.amazon.fr',
    'itunes.apple.com'
  ];
  $(document).on('click', 'a[href]:not(.js-load-modal)', function() {
    // Don't do anything if Google Analytics isn't defined
    if (typeof ga !== "function")
      return;

    var url = $(this).attr('href');
    // has the class?
    var isOutbound = $(this).hasClass('js-outbound-link');
    // is in the domain list?
    if (!isOutbound) {
      $.each(OUTBOUND_DOMAINS, function(){
        if (url.match(this)) {
          isOutbound = true;
          return false; // break loop
        }
      });
    }
    if (isOutbound) {
      ga('send', 'event', 'outbound', 'click', url, { hitCallback: function () { document.location = url; }});
      return false;
    }
  });
})(jQuery);
