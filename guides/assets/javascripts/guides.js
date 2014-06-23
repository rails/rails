$.fn.selectGuide = function(guide) {
  $("select", this).val(guide);
};

var guidesIndex = {
  bind: function() {
    var currentGuidePath = window.location.pathname;
    var currentGuide = currentGuidePath.substring(currentGuidePath.lastIndexOf("/")+1);
    $(".guides-index-small").
      on("change", "select", guidesIndex.navigate).
      selectGuide(currentGuide);
    $(document).on("click", ".more-info-button", function(e){
      e.stopPropagation();
      if ($(".more-info-links").is(":visible")) {
        $(".more-info-links").addClass("s-hidden").unwrap();
      } else {
        $(".more-info-links").wrap("<div class='more-info-container'></div>").removeClass("s-hidden");
      }
    });
    $("#guidesMenu").on("click", function(e) {
      $("#guides").toggle();
      return false;
    });
    $(document).on("click", function(e){
      e.stopPropagation();
      var $button = $(".more-info-button");
      var element;

      // Cross browser find the element that had the event
      if (e.target) element = e.target;
      else if (e.srcElement) element = e.srcElement;

      // Defeat the older Safari bug:
      // http://www.quirksmode.org/js/events_properties.html
      if (element.nodeType === 3) element = element.parentNode;

      var $element = $(element);

      var $container = $element.parents(".more-info-container");

      // We've captured a click outside the popup
      if($container.length === 0){
        $container = $button.next(".more-info-container");
        $container.find(".more-info-links").addClass("s-hidden").unwrap();
      }
    });
  },
  navigate: function(e){
    var $list = $(e.target);
    var url = $list.val();
    window.location = url;
  }
};

// Disable autolink inside example code blocks of guides.
$(document).ready(function() {
  SyntaxHighlighter.defaults['auto-links'] = false;
  SyntaxHighlighter.all();
});
