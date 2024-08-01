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

    var backToTop = createElement("a", "back-to-top");
    backToTop.setAttribute("href", "#");

    document.body.appendChild(backToTop);

    backToTop.addEventListener("click", function(e) {
      e.preventDefault();
      window.scrollTo({ top: 0, behavior: "smooth" });
      resetNavPosition();
    });

    var toggleBackToTop = function() {
      if (window.scrollY > 300) {
        backToTop.classList.add("show");
      } else {
        backToTop.classList.remove("show");
      }
    }

    document.addEventListener("scroll", toggleBackToTop);

    var guidesVersion = document.querySelector("select.guides-version");
    guidesVersion.addEventListener("change", function(e) {
      Turbo.visit(e.target.value);
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

    var mainColElems = Array.from(document.getElementById("mainCol").children);
    var subCol = document.querySelector("#subCol");
    var navLinks = subCol.querySelectorAll("a");
    var DESKTOP_THRESHOLD = 1024;

    var matchingNavLink = function (elem) {
      if(!elem) return;
      var index = mainColElems.indexOf(elem);

      var match;
      while (index >= 0 && !match) {
        var link = mainColElems[index].querySelector(".anchorlink");
        if (link) {
          match = subCol.querySelector('[href="' + link.getAttribute("href") + '"]');
        }
        index--;
      }
      return match;
    }

    var removeHighlight = function () {
      for (var i = 0, n = navLinks.length; i < n; i++) {
        navLinks[i].classList.remove("active");
      }
    }

    var updateHighlight = function (elem) {
      if (window.innerWidth > DESKTOP_THRESHOLD && !elem?.classList.contains("active")) {
        removeHighlight();
        if (!elem) return;
        elem.classList.add("active");
        elem.scrollIntoView({ block: 'center', inline: 'end' });
      }
    }

    var resetNavPosition = function () {
      var chapters = subCol.querySelector(".chapters");
      chapters?.scroll({ top: 0 });
    }

    var belowBottomHalf = function (i) {
      return i.boundingClientRect.bottom > (i.rootBounds.bottom + i.rootBounds.top) / 2;
    }

    var prevElem = function (elem) {
      var index = mainColElems.indexOf(elem);
      if (index <= 0) {
        return null;
      }
      return mainColElems[index - 1];
    }

    var PAGE_LOAD_BUFFER = 1000;

    var navHighlight = function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          updateHighlight(matchingNavLink(entry.target));
        } else if (entry.time >= PAGE_LOAD_BUFFER && belowBottomHalf(entry)) {
          updateHighlight(matchingNavLink(prevElem(entry.target)));
        }
      });
    }

    var observer = new IntersectionObserver(navHighlight, {
      threshold: 0,
      rootMargin: "0% 0px -95% 0px"
    });

    mainColElems.forEach(function (elem) {
      observer.observe(elem);
    })

    observer.observe(document.getElementById("feature"));

    subCol.addEventListener("click", function(e) {
      var link = e.target.closest("a");
      if (link) {
        setTimeout(function() { updateHighlight(link) }, 100);
      }
    })
  });

  // Observe the HTML tag for Google Translate CSS class, to swap our lang direction LTR/RTL.
  var observer = new MutationObserver(function(mutations, _observer) {
    each(mutations, function(mutation) {
      if (mutation.type === "attributes" && mutation.attributeName == "class") {
        mutation.target.dir = mutation.target.classList.contains("translated-rtl") ? "rtl" : "ltr";
      }
    })
  });
  observer.observe(document.querySelector("html"), { attributeFilter: ["class"] });

}).call(this);
