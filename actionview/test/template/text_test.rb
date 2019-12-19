# frozen_string_literal: true

require "abstract_unit"

class TextTest < ActiveSupport::TestCase
  test "format always return :text" do
    assert_equal :text, ActionView::Template::Text.new("").format
  end

  test "identifier should return 'text template'" do
    assert_equal "text template", ActionView::Template::Text.new("").identifier
  end

  test "inspect should return 'text template'" do
    assert_equal "text template", ActionView::Template::Text.new("").inspect
  end

  test "to_str should return a given string" do
    assert_equal "a cat", ActionView::Template::Text.new("a cat").to_str
  end

  test "render should return a given string" do
    assert_equal "a dog", ActionView::Template::Text.new("a dog").render
  end
end
