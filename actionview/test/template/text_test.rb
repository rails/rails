require "abstract_unit"

class TextTest < ActiveSupport::TestCase
  test "formats always return :text" do
    assert_equal [:text], ActionView::Template::Text.new("").formats
  end
end
