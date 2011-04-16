require 'abstract_unit'
require 'sprockets'

class SprocketsHelperTest < ActionView::TestCase
  tests ActionView::Helpers::SprocketsHelper

  attr_accessor :assets

  def setup
    super

    @controller = BasicController.new

    @request = Class.new do
      def protocol() 'http://' end
      def ssl?() false end
      def host_with_port() 'localhost' end
    end.new

    @controller.request = @request

    @assets = Sprockets::Environment.new
    @assets.paths << FIXTURES.join("sprockets/app/javascripts")
    @assets.paths << FIXTURES.join("sprockets/app/stylesheets")

    config.perform_caching = true
  end

  def url_for(*args)
    "http://www.example.com"
  end

  test "javascript path" do
    assert_equal "/assets/application-d41d8cd98f00b204e9800998ecf8427e.js",
      sprockets_javascript_path(:application)

    assert_equal "/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js",
      sprockets_javascript_path("xmlhr")
    assert_equal "/assets/dir/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js",
      sprockets_javascript_path("dir/xmlhr.js")

    assert_equal "/dir/xmlhr.js",
      sprockets_javascript_path("/dir/xmlhr")

    assert_equal "http://www.railsapplication.com/js/xmlhr",
      sprockets_javascript_path("http://www.railsapplication.com/js/xmlhr")
    assert_equal "http://www.railsapplication.com/js/xmlhr.js",
      sprockets_javascript_path("http://www.railsapplication.com/js/xmlhr.js")
  end

  test "javascript include tag" do
    assert_equal '<script src="/assets/application-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      sprockets_javascript_include_tag(:application)

    assert_equal '<script src="/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      sprockets_javascript_include_tag("xmlhr")
    assert_equal '<script src="/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      sprockets_javascript_include_tag("xmlhr.js")
    assert_equal '<script src="http://www.railsapplication.com/xmlhr" type="text/javascript"></script>',
      sprockets_javascript_include_tag("http://www.railsapplication.com/xmlhr")
  end

  test "stylesheet path" do
    assert_equal "/assets/application-d41d8cd98f00b204e9800998ecf8427e.css",
      sprockets_stylesheet_path(:application)

    assert_equal "/assets/style-d41d8cd98f00b204e9800998ecf8427e.css",
      sprockets_stylesheet_path("style")
    assert_equal "/assets/dir/style-d41d8cd98f00b204e9800998ecf8427e.css",
      sprockets_stylesheet_path("dir/style.css")
    assert_equal "/dir/style.css",
      sprockets_stylesheet_path("/dir/style.css")

    assert_equal "http://www.railsapplication.com/css/style",
      sprockets_stylesheet_path("http://www.railsapplication.com/css/style")
    assert_equal "http://www.railsapplication.com/css/style.css",
      sprockets_stylesheet_path("http://www.railsapplication.com/css/style.css")
  end

  test "stylesheet link tag" do
    assert_equal '<link href="/assets/application-d41d8cd98f00b204e9800998ecf8427e.css" media="screen" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag(:application)

    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="screen" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag("style")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="screen" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag("style.css")

    assert_equal '<link href="http://www.railsapplication.com/style.css" media="screen" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag("http://www.railsapplication.com/style.css")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="all" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag("style", :media => "all")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="print" rel="stylesheet" type="text/css" />',
      sprockets_stylesheet_link_tag("style", :media => "print")
  end
end
