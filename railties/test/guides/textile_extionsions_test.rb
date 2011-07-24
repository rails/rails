require 'isolation/abstract_unit'
require 'guides/rails_guides/textile_extensions'

class TextileExtensionsTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation
  include RailsGuides::TextileExtensions
  
  test "tips can handle a single line" do
    expected_output = "<div class='info'><p>this is a single line tip</p></div>"
    assert_equal expected_output, tip('TIP. this is a single line tip')
  end

  def setup
    @multi_line_tip = "This is a multi-line tip.\n" +
      "Isn't it fantastic?"
  end

  test "tips can handle a multi-line tip" do
    expected_output = "<div class='info'><p>#{@multi_line_tip}</p></div>"

    assert_equal expected_output, tip("TIP. #{@multi_line_tip}")
  end

  test "muli-line tips handles text before and after the tip" do
    pre_line = "This is text before hand.\n\n"
    post_line = "\n\nThis is some text after"
    input_text = pre_line +
      "TIP. #{@multi_line_tip}" +
      post_line

    expected_output = pre_line +
      "<div class='info'><p>#{@multi_line_tip}</p></div>" +
      post_line

    assert_equal expected_output, tip(input_text)
  end
end