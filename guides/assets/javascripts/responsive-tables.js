(function() {
  "use strict";
  var switched = false;

  document.querySelectorAll(":not(.syntaxhighlighter)>table").forEach(function(element) {
    element.classList.add("responsive");
  });

  var updateTables = function() {
    if (document.documentElement.clientWidth < 767 && !switched) {
      switched = true;
      document.querySelectorAll("table.responsive").forEach(splitTable);
    } else {
      switched = false;
      document.querySelectorAll(".table-wrapper table.responsive").forEach(unsplitTable);
    }
  }

  document.addEventListener("DOMContentLoaded", updateTables);
  window.addEventListener("resize", updateTables);

  var splitTable = function(original) {
    wrap(original, createElement("div", "table-wrapper"));

    var $copy = original.cloneNode(true);
    $copy.querySelectorAll("td:not(:first-child), th:not(:first-child)").forEach(function(element) {
      element.style.display = "none";
    });
    $copy.classList.remove("responsive");

    original.parentNode.append($copy);
    wrap($copy, createElement("div", "pinned"))
    wrap(original, createElement("div", "scrollable"));
  }

  var unsplitTable = function(original) {
    document.querySelectorAll(".table-wrapper .pinned").forEach(function(element) {
      element.parentNode.removeChild(element);
    });
    unwrap(original.parentNode);
    unwrap(original);
  }
}).call(this);
