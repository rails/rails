(function() {
  "use strict";

  this.wrap = function(elem, wrapper) {
    elem.parentNode.insertBefore(wrapper, elem);
    wrapper.appendChild(elem);
  }

  this.unwrap = function(elem) {
    var wrapper = elem.parentNode;
    wrapper.parentNode.replaceChild(elem, wrapper);
  }

  this.createElement = function(tagName, className) {
    var elem = document.createElement(tagName);
    elem.classList.add(className);
    return elem;
  }

  // For old browsers
  this.each = function(node, callback) {
    var array = Array.prototype.slice.call(node);
    for(var i = 0; i < array.length; i++) callback(array[i]);
  }

  document.addEventListener("turbo:load", function() {
    var guidesMenu = document.getElementById("guidesMenu");
    var guides     = document.getElementById("guides");

    guidesMenu.addEventListener("click", function(e) {
      e.preventDefault();
      guides.classList.toggle("visible");
    });

    each(document.querySelectorAll("#guides a"), function(element) {
      element.addEventListener("click", function(e) {
        guides.classList.toggle("visible");
      });
    });

    document.addEventListener("keyup", function(e) {
      if (e.key === "Escape" && guides.classList.contains("visible")) {
        guides.classList.remove("visible");
      }
    });

    var guidesIndexItem   = document.querySelector("select.guides-index-item");
    var currentGuidePath  = window.location.pathname;
    guidesIndexItem.value = currentGuidePath.substring(currentGuidePath.lastIndexOf("/") + 1) || 'index.html';

    guidesIndexItem.addEventListener("change", function(e) {
      Turbo.visit(e.target.value);
    });

    var moreInfoButton = document.querySelector(".more-info-button");
    var moreInfoLinks  = document.querySelector(".more-info-links");

    moreInfoButton.addEventListener("click", function(e) {
      e.preventDefault();

      if (moreInfoLinks.classList.contains("s-hidden")) {
        wrap(moreInfoLinks, createElement("div", "more-info-container"));
        moreInfoLinks.classList.remove("s-hidden");
      } else {
        moreInfoLinks.classList.add("s-hidden");
        unwrap(moreInfoLinks);
      }
    });

    var clipboard = new ClipboardJS('.clipboard-button');
    clipboard.on('success', function(e) {
      var trigger = e.trigger;
      var triggerLabel = trigger.innerHTML;
      trigger.innerHTML = 'Copied!';
      setTimeout(function(){
        trigger.innerHTML = triggerLabel;
      }, 3000);
      e.clearSelection();
    });
  });
}).call(this);
