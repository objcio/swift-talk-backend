$(function() {
  if (document.body.createTextRange || window.getSelection) {
    // Add buttons and event handlers
    $(".js-has-codeblocks pre:has(>code)").each(function() {
      $(this).prepend('<button class="js-select-code">Select All</button>');
    }).on('click', '.js-select-code', function() {
      $(this).parent().children("code").selectText();
    });
  }
});