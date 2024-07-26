require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/text_helper'

class TextHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TextHelper

  def test_truncate
    assert_equal "Hello World!", truncate("Hello World!", 12)
    assert_equal "Hello Worl...", truncate("Hello World!!", 12)
  end
  
  def test_strip_links
    assert_equal "on my mind", strip_links("<a href='almost'>on my mind</a>")
  end
  
  def test_highlighter
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning",
      highlight("This is a beautiful morning", "beautiful")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful</strong> morning, but also a <strong class=\"highlight\">beautiful</strong> day",
      highlight("This is a beautiful morning, but also a beautiful day", "beautiful")
    )

    assert_equal(
      "This is a <b>beautiful</b> morning, but also a <b>beautiful</b> day",
      highlight("This is a beautiful morning, but also a beautiful day", "beautiful", '<b>\1</b>')
    )
  end
  
  def test_highlighter_with_regexp
    assert_equal(
      "This is a <strong class=\"highlight\">beautiful!</strong> morning",
      highlight("This is a beautiful! morning", "beautiful!")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful! morning</strong>",
      highlight("This is a beautiful! morning", "beautiful! morning")
    )

    assert_equal(
      "This is a <strong class=\"highlight\">beautiful? morning</strong>",
      highlight("This is a beautiful? morning", "beautiful? morning")
    )
  end
  
  def test_excerpt
    assert_equal("...is a beautiful morni...", excerpt("This is a beautiful morning", "beautiful", 5))
    assert_equal("This is a...", excerpt("This is a beautiful morning", "this", 5))
    assert_equal("...iful morning", excerpt("This is a beautiful morning", "morning", 5))
    assert_equal("...iful morning", excerpt("This is a beautiful morning", "morning", 5))
    assert_nil excerpt("This is a beautiful morning", "day")
  end
  
  def test_pluralization
    assert_equal("1 count", pluralize(1, "count"))
    assert_equal("2 counts", pluralize(2, "count"))
  end
end