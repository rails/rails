(function() {
  "use strict";

  var switched = false;

  // For old browsers
  var each = function(node, callback) {
    var array = Array.prototype.slice.call(node);
    for(var i = 0; i < array.length; i++) callback(array[i]);
  }

  each(document.querySelectorAll(":not(.syntaxhighlighter)>table"), function(element) {
    element.classList.add("responsive");
  });

  var updateTables = function() {
    if (document.documentElement.clientWidth < 767 && !switched) {
      switched = true;
      each(document.querySelectorAll("table.responsive"), splitTable);
    } else {
      switched = false;
      each(document.querySelectorAll(".table-wrapper table.responsive"), unsplitTable);
    }
  }

  document.addEventListener("DOMContentLoaded", updateTables);
  window.addEventListener("resize", updateTables);

  var splitTable = function(original) {
    wrap(original, createElement("div", "table-wrapper"));

    var copy = original.cloneNode(true);
    each(copy.querySelectorAll("td:not(:first-child), th:not(:first-child)"), function(element) {
      element.style.display = "none";
    });
    copy.classList.remove("responsive");

    original.parentNode.append(copy);
    wrap(copy, createElement("div", "pinned"))
    wrap(original, createElement("div", "scrollable"));
  }

  var unsplitTable = function(original) {
    each(document.querySelectorAll(".table-wrapper .pinned"), function(element) {
      element.parentNode.removeChild(element);
    });
    unwrap(original.parentNode);
    unwrap(original);
  }
}).call(this);
