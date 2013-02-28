require 'abstract_unit'

# Shamelessly copied from tag_helper_test.rb
class HumanTxtHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::HumansTxtHelper

  def test_human_txt_tag
    assert_equal "<link href=\"/humans.txt\" rel=\"author\" />", humans_txt_tag
  end
end

