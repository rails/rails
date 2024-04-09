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
    var guidesMenuButton = document.getElementById("guidesMenu");
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

      moreInfoLinks.classList.toggle("s-hidden");
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
  });
}).call(this);
