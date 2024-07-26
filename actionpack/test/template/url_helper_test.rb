require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'

class UrlHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper

  def setup
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        "http://www.world.com"
      end
    end
    @controller = @controller.new
  end

  # todo: missing test cases
  def test_link_tag_with_straight_url
    assert "<a href=\"http://www.world.com\">Hello</a>", link_to("Hello", "http://www.world.com")
  end
  
  def test_link_tag_with_javascript_confirm
    assert(
      "<a href=\"http://www.world.com\" onClick=\"return confirm('Are you sure?')\">Hello</a>", 
      link_to("Hello", "http://www.world.com", :confirm => "Are you sure?")
    )
  end
  
  def test_link_unless_current
    @params = { "controller" => "weblog", "action" => "show"}
    assert "<b>Showing</b>", link_to_unless_current("Showing", :action => "show", :controller => "weblog")
    assert "<a href=\"http://www.world.com\">Listing</a>", link_to_unless_current("Listing", :action => "list", :controller => "weblog")
  end
end