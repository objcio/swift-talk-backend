//
// Expandable Plugin
//
// This plugins allows for simple addition/removal of classes based on whether an element
// is in a collapsed (default) or expanded state. Note, this plugin doesn’t actually control
// the visible expansion or collapse of the element, that must be done with CSS.
//
//
// Hook classes:
//
// * .js-expandable: root element of the expandable component
// * .js-expandable-trigger: element which, when clicked, will trigger expansion
//
//
// Hook attributes:
// (can be added on root element (.js-expandable), or any of its descendants (including .js-expandable-trigger))
//
// * data-expandable-collapsed: classes listed in this attribute will be added to the 'class' attribute when an element
//                              is in its collapsed state. Collapsed being default, this happens when JS kicks in.
//                              They will be removed from the 'class' attribute when the element expands.
// * data-expandable-expanded:  classes listed in this attribute will be added to the 'class' attribute when an element
//                              is in its expanded state — that is, when '.js-expandable-trigger' is clicked.
//
//
// Usage Notes:
//
// * The plugin also allows the element to be collapsed again by clicking the button. If this isn’t intended, just
//   hide the .js-expandable-trigger element on expansion, e.g. data-expandable-expanded="hide".
//
// * If you want to change the text of the button to reflect its state, you can use the plugin to control that, .e.g
//   <button class="js-expandable-trigger">
//     <span data-expandable-expanded="hide">Expand</span>
//     <span data-expandable-collapsed="hide" data-expandable-expanded="block">Collapse</span>
//   </button>
//
// * The most progressive way to use the plugin is to style the elements as expanded by default, and then add
//   data-expandable-collapsed to elements which are affected by the collapse. This way, if JS doesn't kick in,
//   the content will still be fully visible.
//
(function ($) {
  $(function () {
    $('.js-expandable').each(function () {

      var $expandable = $(this);

      // Add all classes to elements which only have them when not expanded
      $expandable.find('[data-expandable-collapsed]').addBack('[data-expandable-collapsed]').each(function () {
        $(this).addClass($(this).data('expandable-collapsed'));
      });

      // On click, expand / or collapse again
      $expandable.on('click', '.js-expandable-trigger', function (e) {

        $expandable.find('[data-expandable-collapsed]').addBack('[data-expandable-collapsed]').each(function () {
          $(this).toggleClass($(this).data('expandable-collapsed'));
        });

        $expandable.find('[data-expandable-expanded]').addBack('[data-expandable-expanded]').each(function () {
          $(this).toggleClass($(this).data('expandable-expanded'));
        });

      });
    });
  });
})(jQuery);
