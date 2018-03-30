$(document).on("ready", function() {
  let switched = false
  $("table").not(".syntaxhighlighter").addClass("responsive")

  const updateTables = function() {
    if (($(window).width() < 767) && !switched) {
      switched = true
      $("table.responsive").each(function (i, element) {
        splitTable($(element))
      })
      return true
    } else if (switched && ($(window).width() > 767)) {
      switched = false
      $("table.responsive").each(function (i, element) {
        unsplitTable($(element))
      })
    }
  }

  $(window).load(updateTables)
  $(window).bind("resize", function() {
    updateTables
  })

  const splitTable = function (original) {
    original.wrap("<div class='table-wrapper' />")

    const copy = original.clone()
    copy.find("td:not(:first-child), th:not(:first-child)").css("display", "none")
    copy.removeClass("responsive")

    original.closest(".table-wrapper").append(copy)
    copy.wrap("<div class='pinned' />")
    original.wrap("<div class='scrollable' />")
  }

  const unsplitTable = function (original) {
    original.closest(".table-wrapper").find(".pinned").remove()
    original.unwrap()
    original.unwrap()
  }
})
