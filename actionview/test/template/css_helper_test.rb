# frozen_string_literal: true

require "abstract_unit"

class CssHelperTest < ActionView::TestCase
  tests ActionView::Helpers::CssHelper

  def test_css_classes
    assert_equal "class-1", css_classes("class-1")
    assert_equal "class-1", css_classes("class_1")
    assert_equal "class-1", css_classes(:class_1)
    assert_equal "class-1 class-2", css_classes(:class_1, :class_2)
    assert_equal "class-1 class-2", css_classes('class-1', 'class-2')
    assert_equal "class-1 class-2 class-3", css_classes('class-1', 'class-2', class_3: true)
    assert_equal "class-1 class-2 class-4", css_classes('class-1', 'class-2', class_3: false, class_4: true)
  end
end
