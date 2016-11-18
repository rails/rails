require "abstract_unit"

class TextTest < ActiveSupport::TestCase
  test "formats returns symbol for recognized MIME type" do
    assert_equal [:text], ActionView::Template::Text.new("", :text).formats
  end

  test "formats returns string for recognized MIME type when MIME does not have symbol" do
    foo = Mime::Type.lookup("foo")
    assert_nil foo.to_sym
    assert_equal ["foo"], ActionView::Template::Text.new("", foo).formats
  end

  test "formats returns string for unknown MIME type" do
    assert_equal ["foo"], ActionView::Template::Text.new("", "foo").formats
  end
end
