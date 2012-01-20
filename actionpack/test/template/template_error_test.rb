require "abstract_unit"

class TemplateErrorTest < ActiveSupport::TestCase
  def test_provides_original_message
    error = ActionView::Template::Error.new("test", Exception.new("original"))
    assert_equal "original", error.message
  end

  def test_provides_useful_inspect
    error = ActionView::Template::Error.new("test", Exception.new("original"))
    assert_equal "#<ActionView::Template::Error: original>", error.inspect
  end
end
