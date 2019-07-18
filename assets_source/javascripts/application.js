window.$ = window.jQuery = require('jquery');

require('./objcjs/plugins/scrollTo.jquery.js');
require('./objcjs/utilities/scrollTo.jquery.js');
require('./objcjs/index.js');

require('./app-components.js');


// timestamp links

$(function () {
    window.player = new Vimeo.Player(document.querySelector('iframe'));
  
    $('.js-transcript').find("a[href^='#']").each(function () {
        if (/^\d+$/.test(this.hash.slice(1)) && /^\d{1,2}(:\d{2}){1,2}$/.test(this.innerHTML)) {
            var time = parseInt(this.hash.slice(1));
            $(this)
                .data('time', time)
                .attr('href', '?t='+time)
                .addClass('js-episode-seek js-transcript-cue');
        }
    });

    // Auto-expand transcript if #transcript hash is passed
    if (window.location.hash.match(/^#?transcript$/)) {
        $('#transcript').find('.js-expandable-trigger').trigger('click');
    }

    // Catch clicks on timestamps and forward to player
    $(document).on('click singletap', '.js-episode .js-episode-seek', function (event) {
        if ($(this).data('time') !== undefined) {
            player.setCurrentTime($(this).data('time'));
            player.play();
            event.preventDefault();
        }
    });
});
