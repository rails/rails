require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/url_helper'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/tag_helper'

RequestMock = Struct.new("Request", :request_uri)

class UrlHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::TagHelper

  def setup
    @controller = Class.new do
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com"
      end
    end
    @controller = @controller.new
  end

  # todo: missing test cases
  def test_link_tag_with_straight_url
    assert_equal "<a href=\"http://www.example.com\">Hello</a>", link_to("Hello", "http://www.example.com")
  end

  def test_link_tag_with_javascript_confirm
    assert_equal(
      "<a href=\"http://www.example.com\" onclick=\"return confirm('Are you sure?');\">Hello</a>",
      link_to("Hello", "http://www.example.com", :confirm => "Are you sure?")
    )
    assert_equal(
      "<a href=\"http://www.example.com\" onclick=\"return confirm('You can\\'t possibly be sure, can you?');\">Hello</a>", 
      link_to("Hello", "http://www.example.com", :confirm => "You can't possibly be sure, can you?")
    )
  end

  def test_link_image_to
    assert_equal(
      "<a href=\"http://www.example.com\"><img alt=\"Rss\" border=\"0\" height=\"45\" src=\"/images/rss.png\" width=\"30\" /></a>",
      link_image_to("rss", "http://www.example.com", "size" => "30x45", "border" => "0")
    )

    assert_equal(
      "<a class=\"admin\" href=\"http://www.example.com\"><img alt=\"Feed\" height=\"45\" src=\"/images/rss.gif\" width=\"30\" /></a>",
      link_image_to("rss.gif", "http://www.example.com", "size" => "30x45", "alt" => "Feed", "class" => "admin")
    )

    assert_equal link_image_to("rss", "http://www.example.com", "size" => "30x45"),
                 link_image_to("rss", "http://www.example.com", :size => "30x45")
    assert_equal link_image_to("rss.gif", "http://www.example.com", "size" => "30x45", "alt" => "Feed", "class" => "admin"),
                 link_image_to("rss.gif", "http://www.example.com", :size => "30x45", :alt => "Feed", :class => "admin")
  end

  def test_link_unless_current
    @request = RequestMock.new("http://www.example.com")
    assert_equal "Showing", link_to_unless_current("Showing", :action => "show", :controller => "weblog")
    @request = RequestMock.new("http://www.example.org")
    assert "<a href=\"http://www.example.com\">Listing</a>", link_to_unless_current("Listing", :action => "list", :controller => "weblog")

    @request = RequestMock.new("http://www.example.com")
    assert_equal "Showing", link_to_unless_current("Showing", :action => "show", :controller => "weblog", :id => 1)
  end

  def test_mail_to
    assert_equal "<a href=\"mailto:david@loudthinking.com\">david@loudthinking.com</a>", mail_to("david@loudthinking.com")
    assert_equal "<a href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>", mail_to("david@loudthinking.com", "David Heinemeier Hansson")
    assert_equal(
      "<a class=\"admin\" href=\"mailto:david@loudthinking.com\">David Heinemeier Hansson</a>",
      mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin")
    )
    assert_equal mail_to("david@loudthinking.com", "David Heinemeier Hansson", "class" => "admin"),
                 mail_to("david@loudthinking.com", "David Heinemeier Hansson", :class => "admin")
  end

  def test_link_with_nil_html_options
    assert_equal "<a href=\"http://www.example.com\">Hello</a>", link_to("Hello", {:action => 'myaction'}, nil)
  end
end
