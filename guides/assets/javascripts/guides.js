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
      var backToTop = document.querySelector('.back-to-top');

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

    // ============ highlight chapter navigation ============
    var columnMain = document.getElementById("column-main");
    var columnSide = document.getElementById("column-side");
    var columnMainElements = Array.from(columnMain.querySelectorAll('h2, h3, p, div, ol, ul'))

    /**
     * Find the matching navigation link (in the side bar) for the given content
     * in the main column.
     *
     * @param elem {null | undefined | HTMLElement}
     * @returns {HTMLAnchorElement | undefined} */
    var matchingNavLink = function (elem) {
      if(!elem) {
        elem = columnMainElements[0];
      }

      for (var index = columnMainElements.indexOf(elem); index >= 0; index--) {
        var link = columnMainElements[index].querySelector("a.anchorlink[href]:not([href=''])");

        if (link) {
          return columnSide.querySelector('a[href="' + link.getAttribute("href") + '"]');
        }
      }
    }

    /**
     * Removes the currently highlighted element from aria-current which also
     * updates the styling to no longer highlight it.
     */
    var removeHighlight = function () {
      columnSide
        .querySelectorAll('[aria-current="true"]')
        .forEach((highlighted) => {
          highlighted.removeAttribute('aria-current');
        })
    }

    /**
     * Sets aria-current on the given element which also updates the styling to
     * highlight it.
     *
     * @param {HTMLElement | null | undefined} elem
     * @returns
     */
    var updateHighlight = function (elem) {
      if (!elem || elem.hasAttribute('aria-current')) {
        return
      };

      removeHighlight();
      elem.setAttribute('aria-current', 'true');

      // You may be tempted to scroll the chapter list, but on some OS-browser
      // combinations, this will stop smooth scrolling of the main document.
      // This is the case with setting scrollTop & scrollIntoView.
      //
      // eg. elem.scrollIntoView(...)
      //     columnSide.querySelector('ol').scrollTop = ...
    }

    var prevElem = function (elem) {
      var index = columnMainElements.indexOf(elem);
      return columnMainElements[index - 1] || null;
    }

    var nextElem = function (elem) {
      var index = columnMainElements.indexOf(elem);
      return columnMainElements[index + 1] || null;
    }

    var didThisIntersectionHappenAtTop = (entry) => {
      if (!entry.rootBounds) {
        return false
      }

      return entry.rootBounds.bottom - entry.boundingClientRect.bottom > entry.rootBounds.bottom / 2;
    }

    var direction = 'up'
    var prevYPosition = 0

    /**
     * The callback for the intersection observer which finds the relevant
     * content section and matching navigation link.
     *
     * @type {IntersectionObserverCallback}
     **/
    var onIntersect = (entries) => {
      if (document.scrollingElement.scrollTop > prevYPosition) {
        direction = 'down';
      } else {
        direction = 'up';
      }

      prevYPosition = document.scrollingElement.scrollTop;

      var intersecting = []

      entries.forEach((entry) => {
        var intersectionAtTop = didThisIntersectionHappenAtTop(entry);

        if (intersectionAtTop && entry.isIntersecting) {
          // The interaction observer creates at most 3 events per element. One
          // at 0, one around 0.5 and one around 1 ratio of intersecting.
          //
          // When scrolling half-past the element, look at the next one instead.
          // This is necessary for different handling of scroll-padding, and
          // the offset at which an anchor will be focused & scrolled to after
          // navigating to it.
          var target = direction === 'down' && entry.intersectionRatio < 0.6 ? nextElem(entry.target) : entry.target;
          intersecting.push(target);
        }
      })

      // Multiple elements may be intersecting at any moment, but in that case
      // depending on the direction the lowest or highest on the page is leading
      // and should be used to find the matching link. This is important for
      // scrolling via the chapter anchor list.
      if (intersecting.length > 0) {
        var target = intersecting[direction === 'down' ? intersecting.length - 1 : 0];
        var link = matchingNavLink(target);
        updateHighlight(link);
      }
    }

    var observer = new IntersectionObserver(onIntersect, {
      // The different thresholds are required to be able to scroll up and
      // instantly trigger the callback after smooth-scrolling from low on the
      // page to higher up.
      threshold: [0, 0.5, 1],

      // The root margin is offsetted by half the scroll-padding-top
      rootMargin: "-10px 0px 0px 0px"
    });

    columnMainElements.forEach(function (elem) {
      observer.observe(elem);
    })
  });

  // ------------ end of highlight chapter navigation ------------

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
