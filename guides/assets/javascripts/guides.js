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

  // Viewable on local
  if (window.location.protocol === "file:") Turbolinks.supported = false;

  document.addEventListener("turbolinks:load", function() {
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

    var guidesIndexItem   = document.querySelector("select.guides-index-item");
    var currentGuidePath  = window.location.pathname;
    guidesIndexItem.value = currentGuidePath.substring(currentGuidePath.lastIndexOf("/") + 1);

    guidesIndexItem.addEventListener("change", function(e) {
      if (Turbolinks.supported) {
        Turbolinks.visit(e.target.value);
      } else {
        window.location = e.target.value;
      }
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
  });
}).call(this);
