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
    assert_equal "<a href=\"http://www.world.com\">Hello</a>", link_to("Hello", "http://www.world.com")
  end
  
  def test_link_tag_with_javascript_confirm
    assert_equal(
      "<a href=\"http://www.world.com\" onclick=\"return confirm('Are you sure?');\">Hello</a>", 
      link_to("Hello", "http://www.world.com", :confirm => "Are you sure?")
    )
  end
  
  def test_link_to_image
    assert_equal(
      "<a href=\"http://www.world.com\"><img alt=\"Rss\" border=\"0\" height=\"45\" src=\"/images/rss.png\" width=\"30\" /></a>", 
      link_to_image("rss", "http://www.world.com", "size" => "30x45")
    )

    assert_equal(
      "<a class=\"admin\" href=\"http://www.world.com\"><img alt=\"Feed\" border=\"0\" height=\"45\" src=\"/images/rss.gif\" width=\"30\" /></a>", 
      link_to_image("rss.gif", "http://www.world.com", "size" => "30x45", "alt" => "Feed", "class" => "admin")
    )
  end
  
  def test_link_unless_current
    @params = { "controller" => "weblog", "action" => "show"}
    assert_equal "Showing", link_to_unless_current("Showing", :action => "show", :controller => "weblog")
    assert "<a href=\"http://www.world.com\">Listing</a>", link_to_unless_current("Listing", :action => "list", :controller => "weblog")

    @params = { "controller" => "weblog", "action" => "show", "id" => "1"}
    assert_equal "Showing", link_to_unless_current("Showing", :action => "show", :controller => "weblog", :id => 1)
  end

  def test_mail_to
    assert_equal "<a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>", mail_to("david@loudthinking.com")
    assert_equal "<a href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>", mail_to("david@loudthinking.com", "David Heinemeier Hansson")
    assert_equal(
      "<a class=\"admin\" href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>", 
      mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin")
    )
  end
  
  def test_link_with_nil_html_options
    assert_equal "<a href=\"http://www.world.com\">Hello</a>", link_to("Hello", {:action => 'myaction'}, nil)
  end
end
