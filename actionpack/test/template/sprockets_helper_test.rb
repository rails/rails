require 'abstract_unit'
require 'sprockets'
require 'sprockets/helpers/rails_helper'
require 'mocha'

class SprocketsHelperTest < ActionView::TestCase
  tests Sprockets::Helpers::RailsHelper

  attr_accessor :assets

  def setup
    super

    @controller = BasicController.new
    @controller.stubs(:params).returns({})

    @request = Class.new do
      def protocol() 'http://' end
      def ssl?() false end
      def host_with_port() 'localhost' end
    end.new

    @controller.request = @request

    @assets = Sprockets::Environment.new
    @assets.paths << FIXTURES.join("sprockets/app/javascripts")
    @assets.paths << FIXTURES.join("sprockets/app/stylesheets")
    @assets.paths << FIXTURES.join("sprockets/app/images")

    application = Object.new
    Rails.stubs(:application).returns(application)
    application.stubs(:config).returns(config)
    application.stubs(:assets).returns(@assets)

    config.perform_caching = true
  end

  def url_for(*args)
    "http://www.example.com"
  end

  test "asset path" do
    assert_equal "/assets/logo-9c0a079bdd7701d7e729bd956823d153.png",
      asset_path("logo.png")

    assert_equal "/images/logo",
      asset_path("/images/logo")
    assert_equal "/images/logo.gif",
      asset_path("/images/logo.gif")

    assert_equal "/dir/audio",
      asset_path("/dir/audio")

    assert_equal "http://www.example.com/video/play",
      asset_path("http://www.example.com/video/play")
    assert_equal "http://www.example.com/video/play.mp4",
      asset_path("http://www.example.com/video/play.mp4")
  end

  test "asset path with relative url root" do
    @controller.config.relative_url_root = "/collaboration/hieraki"
    assert_equal "/collaboration/hieraki/images/logo.gif",
     asset_path("/images/logo.gif")
  end

  test "javascript path" do
    assert_equal "/assets/application-d41d8cd98f00b204e9800998ecf8427e.js",
      asset_path(:application, "js")

    assert_equal "/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js",
      asset_path("xmlhr", "js")
    assert_equal "/assets/dir/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js",
      asset_path("dir/xmlhr.js", "js")

    assert_equal "/dir/xmlhr.js",
      asset_path("/dir/xmlhr", "js")

    assert_equal "http://www.example.com/js/xmlhr",
      asset_path("http://www.example.com/js/xmlhr", "js")
    assert_equal "http://www.example.com/js/xmlhr.js",
      asset_path("http://www.example.com/js/xmlhr.js", "js")
  end

  test "javascript include tag" do
    assert_equal '<script src="/assets/application-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      javascript_include_tag(:application)

    assert_equal '<script src="/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      javascript_include_tag("xmlhr")
    assert_equal '<script src="/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js" type="text/javascript"></script>',
      javascript_include_tag("xmlhr.js")
    assert_equal '<script src="http://www.example.com/xmlhr" type="text/javascript"></script>',
      javascript_include_tag("http://www.example.com/xmlhr")

    assert_equal "<script src=\"/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js?body=1\" type=\"text/javascript\"></script>\n<script src=\"/assets/application-d41d8cd98f00b204e9800998ecf8427e.js?body=1\" type=\"text/javascript\"></script>",
      javascript_include_tag(:application, :debug => true)

    assert_equal  "<script src=\"/assets/xmlhr-d41d8cd98f00b204e9800998ecf8427e.js\" type=\"text/javascript\"></script>\n<script src=\"/assets/extra-d41d8cd98f00b204e9800998ecf8427e.js\" type=\"text/javascript\"></script>",
      javascript_include_tag("xmlhr", "extra")
  end

  test "stylesheet path" do
    assert_equal "/assets/application-68b329da9893e34099c7d8ad5cb9c940.css", asset_path(:application, "css")

    assert_equal "/assets/style-d41d8cd98f00b204e9800998ecf8427e.css", asset_path("style", "css")
    assert_equal "/assets/dir/style-d41d8cd98f00b204e9800998ecf8427e.css", asset_path("dir/style.css", "css")
    assert_equal "/dir/style.css", asset_path("/dir/style.css", "css")

    assert_equal "http://www.example.com/css/style",
      asset_path("http://www.example.com/css/style", "css")
    assert_equal "http://www.example.com/css/style.css",
      asset_path("http://www.example.com/css/style.css", "css")
  end

  test "stylesheet link tag" do
    assert_equal '<link href="/assets/application-68b329da9893e34099c7d8ad5cb9c940.css" media="screen" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag(:application)

    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="screen" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("style")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="screen" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("style.css")

    assert_equal '<link href="http://www.example.com/style.css" media="screen" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("http://www.example.com/style.css")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="all" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("style", :media => "all")
    assert_equal '<link href="/assets/style-d41d8cd98f00b204e9800998ecf8427e.css" media="print" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("style", :media => "print")

    assert_equal "<link href=\"/assets/style-d41d8cd98f00b204e9800998ecf8427e.css?body=1\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />\n<link href=\"/assets/application-68b329da9893e34099c7d8ad5cb9c940.css?body=1\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />",
      stylesheet_link_tag(:application, :debug => true)

    assert_equal "<link href=\"/assets/style-d41d8cd98f00b204e9800998ecf8427e.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />\n<link href=\"/assets/extra-d41d8cd98f00b204e9800998ecf8427e.css\" media=\"screen\" rel=\"stylesheet\" type=\"text/css\" />",
      stylesheet_link_tag("style", "extra")
  end
end
