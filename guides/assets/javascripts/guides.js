function guideMenu(){
  if (document.getElementById('guides').style.display == "none") {
    document.getElementById('guides').style.display = "block";
  } else {
    document.getElementById('guides').style.display = "none";
  }
}

$.fn.selectGuide = function(guide){
  $("select", this).val(guide);
}

guidesIndex = {
  bind: function(){
    var currentGuidePath = window.location.pathname;
    var currentGuide = currentGuidePath.substring(currentGuidePath.lastIndexOf("/")+1);
    $(".guides-index-small").
      on("change", "select", guidesIndex.navigate).
      selectGuide(currentGuide);
    $(".more-info-button:visible").click(function(e){
      e.stopPropagation();
      if($(".more-info-links").is(":visible")){
        $(".more-info-links").addClass("s-hidden").unwrap();
      } else {
        $(".more-info-links").wrap("<div class='more-info-container'></div>").removeClass("s-hidden");
      }
      $(document).on("click", function(e){
        var $button = $(".more-info-button");
        var element;

        // Cross browser find the element that had the event
        if (e.target) element = e.target;
        else if (e.srcElement) element = e.srcElement;

        // Defeat the older Safari bug:
        // http://www.quirksmode.org/js/events_properties.html
        if (element.nodeType == 3) element = element.parentNode;

        var $element = $(element);

        var $container = $element.parents(".more-info-container");

        // We've captured a click outside the popup
        if($container.length == 0){
          $container = $button.next(".more-info-container");
          $container.find(".more-info-links").addClass("s-hidden").unwrap();
          $(document).off("click");
        }
      });
    });
  },
  navigate: function(e){
    var $list = $(e.target);
    url = $list.val();
    window.location = url;
  }
}
