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

(function(){
      'use strict';

      var Linkifier = function(){
        var MAPPINGS =  {
            "active_support" : "activesupport",
            "action_view" : "actionview",
            "action_controller" : "actionpack",
            "abstract_controller" : "actionpack",
            "action_pack" : "actionpack",
            "action_dispatch" : "actionpack",
            "active_job" : "activejob",
            "active_model" : "activemodel",
            "action_mailer" : "actionmailer",
            "active_record" : "activerecord",
          }, ret = {};

        //get a github address for a source address
        //uses document.RAILS_VERSION or master as the github branch to resolve relatively to
        ret.src_url = function(path){
          var prefix = "https://github.com/rails/rails/tree/" + (document.RAILS_VERSION || 'master');
          var root = path.split("/")[0];
          return prefix + '/' + MAPPINGS[root] + '/lib/' + path;
        };
        ret.linkify = function(path) {
          return "<a href='" + this.src_url(path) + "'>" + path + "</a>";
        };
        return ret;
      }();


  // Disable autolink inside example code blocks of guides.
  $(document).ready(function() {
    $(".src_ref code").each(function(){
      this.innerHTML = Linkifier.linkify(this.innerHTML);
    });
    SyntaxHighlighter.defaults['auto-links'] = false;
    SyntaxHighlighter.all();
  });

})();
