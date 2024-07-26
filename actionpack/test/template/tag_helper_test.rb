require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'

class TagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper

  def test_tag
    assert_equal "<p class=\"show\" />", tag("p", "class" => "show")
  end
  
  def test_content_tag
    assert_equal "<a href=\"create\">Create</a>", content_tag("a", "Create", "href" => "create")
  end

  # FIXME: Test form tag
end