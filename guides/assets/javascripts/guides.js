(function () {
  "use strict";

  this.wrap = function (elem, wrapper) {
    elem.parentNode.insertBefore(wrapper, elem);
    wrapper.appendChild(elem);
  };

  this.unwrap = function (elem) {
    var wrapper = elem.parentNode;
    wrapper.parentNode.replaceChild(elem, wrapper);
  };

  this.createElement = function (tagName, className) {
    var elem = document.createElement(tagName);
    elem.classList.add(className);
    return elem;
  };

  // For old browsers
  this.each = function (node, callback) {
    var array = Array.prototype.slice.call(node);
    for (var i = 0; i < array.length; i++) callback(array[i]);
  };

  document.addEventListener("turbo:load", function () {
    // The guides menu anchor is overridden to expand an element with the entire
    // index on the same page. It is important that both the visibility is
    // changed and that the aria-expanded attribute is toggled.
    //
    // Additionally, keyboard users should be able to close these guides by
    // pressing escape, which is the standard key to collapse expanded elements.
    var guidesMenuButton = document.getElementById("guides-menu-button");

    // The link is now acting as a button (but still allows for open in new tab).
    guidesMenuButton.setAttribute('role', 'button')
    guidesMenuButton.setAttribute('aria-controls', guidesMenuButton.getAttribute('data-aria-controls'));
    guidesMenuButton.setAttribute('aria-expanded', guidesMenuButton.getAttribute('data-aria-expanded'));
    guidesMenuButton.removeAttribute('data-aria-controls');
    guidesMenuButton.removeAttribute('data-aria-expanded');

    var guides = document.getElementById(
      guidesMenuButton.getAttribute("aria-controls")
    );

    var toggleGuidesMenu = function () {
      var nextExpanded =
        guidesMenuButton.getAttribute("aria-expanded") === "false";

      guides.classList.toggle("visible");
      guidesMenuButton.setAttribute(
        "aria-expanded",
        nextExpanded ? "true" : "false"
      );

      var focusElement = nextExpanded
        ? guides.querySelector("a")
        : guidesMenuButton;
      focusElement.focus();
    };

    guidesMenuButton.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();

      toggleGuidesMenu();
    });

    each(document.querySelectorAll("#guides a"), function (element) {
      element.addEventListener("click", function () {
        toggleGuidesMenu();
      });
    });

    document.addEventListener("click", function (e) {
      if (guidesMenuButton.getAttribute("aria-expanded") === "false") {
        return;
      }


      if (e.target instanceof Element) {
        if (
          !e.target.closest(
            "#" + guidesMenuButton.getAttribute("aria-controls")
          )
        ) {
          toggleGuidesMenu();
        }
      }
    });

    document.addEventListener("keydown", function (e) {
      if (
        e.key === "Escape" &&
        guidesMenuButton.getAttribute("aria-expanded") === "true"
      ) {
        toggleGuidesMenu();
      }
    });

    // If the browser supports the animation timeline CSS feature, JavaScript is
    // not required for the element to be made visible at a certain scroll
    // position.
    if (
      typeof window.CSS === "undefined" ||
      typeof window.CSS.supports === "undefined" ||
      !CSS.supports("(animation-timeline: scroll())")
    ) {
      var toggleBackToTop = function () {
        if (window.scrollY > 300) {
          backToTop.classList.add("show");
        } else {
          backToTop.classList.remove("show");
        }
      };

      document.addEventListener("scroll", toggleBackToTop);
    }

    // Automatically browse when the version selector is changed. It is
    // important that this behaviour is communicated to the user, for example
    // via an accessible label.
    var guidesVersion = document.querySelector("select.guides-version");
    guidesVersion.addEventListener("change", function (e) {
      Turbo.visit(e.target.value);
    });

    var guidesIndexItem = document.querySelector("select.guides-index-item");
    var currentGuidePath = window.location.pathname;
    guidesIndexItem.value =
      currentGuidePath.substring(currentGuidePath.lastIndexOf("/") + 1) ||
      "index.html";
    guidesIndexItem.addEventListener("change", function (e) {
      Turbo.visit(e.target.value);
    });

    // The move info button expands an element with several links. It is
    // important that both the visibility is changed and that the aria-expanded
    // attribute is toggled.
    //
    // Additionally, keyboard users should be able to close this menu by
    // pressing escape, which is the standard key to collapse expanded elements.
    var moreInfoButton = document.getElementById("more-info");
    var moreInfoLinks = document.getElementById(
      moreInfoButton.getAttribute("aria-controls")
    );

    var toggleMoreInfoContent = function () {
      var nextExpanded =
        moreInfoButton.getAttribute("aria-expanded") === "false";

      moreInfoLinks.classList.toggle("hidden");
      moreInfoButton.setAttribute(
        "aria-expanded",
        nextExpanded ? "true" : "false"
      );

      var focusElement = nextExpanded
        ? moreInfoLinks.querySelector("a")
        : moreInfoButton;
      focusElement.focus();
    };

    moreInfoButton.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();

      toggleMoreInfoContent();
    });

    document.addEventListener("keydown", function (e) {
      if (
        e.key === "Escape" &&
        moreInfoButton.getAttribute("aria-expanded") === "true"
      ) {
        toggleMoreInfoContent();
      }
    });

    document.addEventListener("click", function (e) {
      if (moreInfoButton.getAttribute("aria-expanded") === "false") {
        return;
      }

      if (e.target instanceof Element) {
        if (!e.target.closest(".more-info-container")) {
          toggleMoreInfoContent();
        }
      }
    });

    //
    var clipboard = new ClipboardJS(".clipboard-button");
    clipboard.on("success", function (e) {
      var trigger = e.trigger;
      var triggerLabel = trigger.innerHTML;
      trigger.innerHTML = "Copied!";
      setTimeout(function () {
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
