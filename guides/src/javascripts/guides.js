$.fn.selectGuide = function (guide) {
  $("select", this).val(guide)
}

const guidesIndex = {
  bind: function () {
    const currentGuidePath = window.location.pathname
    const currentGuide = currentGuidePath.substring(currentGuidePath.lastIndexOf("/") + 1)

    $(".guides-index-small").
      on("change", "select", guidesIndex.navigate).
      selectGuide(currentGuide)

    $(document).on("click", ".more-info-button", function (e) {
      e.stopPropagation()

      if ($(".more-info-links").is(":visible")) {
        $(".more-info-links").addClass("s-hidden").unwrap()
      } else {
        $(".more-info-links").wrap("<div class='more-info-container'></div>").removeClass("s-hidden")
      }
    })

    $("#guidesMenu").on("click", function (e) {
      $("#guides").toggle()
      return false
    })

    $(document).on("click", function (e) {
      e.stopPropagation()
      const $button = $(".more-info-button")
      let element

      // Cross browser find the element that had the event
      if (e.target) element = e.target
      else if (e.srcElement) element = e.srcElement

      // Defeat the older Safari bug:
      // http://www.quirksmode.org/js/events_properties.html
      if (element.nodeType === 3) element = element.parentNode

      const $element = $(element)
      let $container = $element.parents(".more-info-container")

      // We've captured a click outside the popup
      if ($container.length === 0) {
        $container = $button.next(".more-info-container")
        $container.find(".more-info-links").addClass("s-hidden").unwrap()
      }
    })
  },

  navigate: function (e) {
    const $list = $(e.target)
    const url = $list.val()
    window.location = url
  }
}

$(document).on("ready", function() {
  $(guidesIndex.bind)
})
