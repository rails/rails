require 'abstract_unit'
require 'sprockets'
require 'sprockets/helpers/rails_helper'
require 'mocha'

class SprocketsHelperTest < ActionView::TestCase
  include Sprockets::Helpers::RailsHelper

  attr_accessor :assets

  class MockRequest
    def protocol() 'http://' end
    def ssl?() false end
    def host_with_port() 'localhost' end
  end

  def setup
    super

    @controller         = BasicController.new
    @controller.request = MockRequest.new

    @assets = Sprockets::Environment.new
    @assets.append_path(FIXTURES.join("sprockets/app/javascripts"))
    @assets.append_path(FIXTURES.join("sprockets/app/stylesheets"))
    @assets.append_path(FIXTURES.join("sprockets/app/images"))
    @assets.append_path(FIXTURES.join("sprockets/app/fonts"))

    application = Struct.new(:config, :assets).new(config, @assets)
    Rails.stubs(:application).returns(application)
    @config = config
    @config.perform_caching = true
    @config.assets.digest = true
    @config.assets.compile = true
  end

  def url_for(*args)
    "http://www.example.com"
  end

  def config
    @controller ? @controller.config : @config
  end

  def compute_host(source, request, options = {})
    raise "Should never get here"
  end

  test "asset_path" do
    assert_match %r{/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
    assert_match %r{/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png", :digest => true)
    assert_match %r{/assets/logo.png},
      asset_path("logo.png", :digest => false)
  end

  test "custom_asset_path" do
    @config.assets.prefix = '/s'
    assert_match %r{/s/logo-[0-9a-f]+.png},
      asset_path("logo.png")
    assert_match %r{/s/logo-[0-9a-f]+.png},
      asset_path("logo.png", :digest => true)
    assert_match %r{/s/logo.png},
      asset_path("logo.png", :digest => false)
  end

  test "asset_path with root relative assets" do
    assert_equal "/images/logo",
      asset_path("/images/logo")
    assert_equal "/images/logo.gif",
      asset_path("/images/logo.gif")

    assert_equal "/dir/audio",
      asset_path("/dir/audio")
  end

  test "asset_path with absolute urls" do
    assert_equal "http://www.example.com/video/play",
      asset_path("http://www.example.com/video/play")
    assert_equal "http://www.example.com/video/play.mp4",
      asset_path("http://www.example.com/video/play.mp4")
  end

  test "with a simple asset host the url should default to protocol relative" do
    @controller.config.default_asset_host_protocol = :relative
    @controller.config.asset_host = "assets-%d.example.com"
    assert_match %r{^//assets-\d.example.com/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "with a simple asset host the url can be changed to use the request protocol" do
    @controller.config.asset_host = "assets-%d.example.com"
    @controller.config.default_asset_host_protocol = :request
    assert_match %r{http://assets-\d.example.com/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "With a proc asset host that returns no protocol the url should be protocol relative" do
    @controller.config.default_asset_host_protocol = :relative
    @controller.config.asset_host = Proc.new do |asset|
      "assets-999.example.com"
    end
    assert_match %r{^//assets-999.example.com/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "with a proc asset host that returns a protocol the url use it" do
    @controller.config.asset_host = Proc.new do |asset|
      "http://assets-999.example.com"
    end
    assert_match %r{http://assets-999.example.com/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "stylesheets served with a controller in scope can access the request" do
    config.asset_host = Proc.new do |asset, request|
      assert_not_nil request
      "http://assets-666.example.com"
    end
    assert_match %r{http://assets-666.example.com/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "stylesheets served without a controller in scope cannot access the request" do
    @controller = nil
    @config.asset_host = Proc.new do |asset, request|
      fail "This should not have been called."
    end
    assert_raises ActionController::RoutingError do
      asset_path("logo.png")
    end
    @config.asset_host = method :compute_host
    assert_raises ActionController::RoutingError do
      asset_path("logo.png")
    end
  end

  test "image_tag" do
    assert_dom_equal '<img alt="Xml" src="/assets/xml.png" />', image_tag("xml.png")
  end

  test "image_path" do
    assert_match %r{/assets/logo-[0-9a-f]+.png},
      image_path("logo.png")

    assert_match %r{/assets/logo-[0-9a-f]+.png},
      path_to_image("logo.png")
  end

  test "font_path" do
    assert_match %r{/assets/font-[0-9a-f]+.ttf},
      font_path("font.ttf")

    assert_match %r{/assets/font-[0-9a-f]+.ttf},
      path_to_font("font.ttf")
  end

  test "javascript_path" do
    assert_match %r{/assets/application-[0-9a-f]+.js},
      javascript_path("application")

    assert_match %r{/assets/application-[0-9a-f]+.js},
      javascript_path("application.js")

    assert_match %r{/assets/application-[0-9a-f]+.js},
      path_to_javascript("application.js")
  end

  test "stylesheet_path" do
    assert_match %r{/assets/application-[0-9a-f]+.css},
      stylesheet_path("application")

    assert_match %r{/assets/application-[0-9a-f]+.css},
      stylesheet_path("application.css")

    assert_match %r{/assets/application-[0-9a-f]+.css},
      path_to_stylesheet("application.css")
  end

  test "stylesheets served without a controller in do not use asset hosts when the default protocol is :request" do
    @controller = nil
    @config.asset_host = "assets-%d.example.com"
    @config.default_asset_host_protocol = :request
    @config.perform_caching = true

    assert_match %r{/assets/logo-[0-9a-f]+.png},
      asset_path("logo.png")
  end

  test "asset path with relative url root" do
    @controller.config.relative_url_root = "/collaboration/hieraki"
    assert_equal "/collaboration/hieraki/images/logo.gif",
     asset_path("/images/logo.gif")
  end

  test "asset path with relative url root when controller isn't present but relative_url_root is" do
    @controller = nil
    @config.relative_url_root = "/collaboration/hieraki"
    assert_equal "/collaboration/hieraki/images/logo.gif",
     asset_path("/images/logo.gif")
  end

  test "font path through asset_path" do
    assert_match %r{/assets/font-[0-9a-f]+.ttf},
      asset_path('font.ttf')

    assert_match %r{/assets/dir/font-[0-9a-f]+.ttf},
      asset_path("dir/font.ttf")

    assert_equal "http://www.example.com/fonts/font.ttf",
      asset_path("http://www.example.com/fonts/font.ttf")
  end

  test "javascript path through asset_path" do
    assert_match %r{/assets/application-[0-9a-f]+.js},
      asset_path(:application, :ext => "js")

    assert_match %r{/assets/xmlhr-[0-9a-f]+.js},
      asset_path("xmlhr", :ext => "js")
    assert_match %r{/assets/dir/xmlhr-[0-9a-f]+.js},
      asset_path("dir/xmlhr.js", :ext => "js")

    assert_equal "/dir/xmlhr.js",
      asset_path("/dir/xmlhr", :ext => "js")

    assert_equal "http://www.example.com/js/xmlhr",
      asset_path("http://www.example.com/js/xmlhr", :ext => "js")
    assert_equal "http://www.example.com/js/xmlhr.js",
      asset_path("http://www.example.com/js/xmlhr.js", :ext => "js")
  end

  test "javascript include tag" do
    assert_match %r{<script src="/assets/application-[0-9a-f]+.js" type="text/javascript"></script>},
      javascript_include_tag(:application)
    assert_match %r{<script src="/assets/application-[0-9a-f]+.js" type="text/javascript"></script>},
      javascript_include_tag(:application, :digest => true)
    assert_match %r{<script src="/assets/application.js" type="text/javascript"></script>},
      javascript_include_tag(:application, :digest => false)

    assert_match %r{<script src="/assets/xmlhr-[0-9a-f]+.js" type="text/javascript"></script>},
      javascript_include_tag("xmlhr")
    assert_match %r{<script src="/assets/xmlhr-[0-9a-f]+.js" type="text/javascript"></script>},
      javascript_include_tag("xmlhr.js")
    assert_equal '<script src="http://www.example.com/xmlhr" type="text/javascript"></script>',
      javascript_include_tag("http://www.example.com/xmlhr")

    assert_match %r{<script src=\"/assets/xmlhr-[0-9a-f]+.js" type=\"text/javascript\"></script>\n<script src=\"/assets/extra-[0-9a-f]+.js" type=\"text/javascript\"></script>},
      javascript_include_tag("xmlhr", "extra")

    assert_match %r{<script src="/assets/xmlhr-[0-9a-f]+.js\?body=1" type="text/javascript"></script>\n<script src="/assets/application-[0-9a-f]+.js\?body=1" type="text/javascript"></script>},
      javascript_include_tag(:application, :debug => true)

    assert_match %r{<script src="/assets/jquery.plugin.js" type="text/javascript"></script>},
      javascript_include_tag('jquery.plugin', :digest => false)

    assert_match %r{\A<script src="/assets/xmlhr-[0-9a-f]+.js" type="text/javascript"></script>\Z},
      javascript_include_tag("xmlhr", "xmlhr")

    assert_match %r{\A<script src="/assets/foo.min-[0-9a-f]+.js" type="text/javascript"></script>\Z},
      javascript_include_tag("foo.min")

    @config.assets.compile = true
    @config.assets.debug = true
    assert_match %r{<script src="/javascripts/application.js" type="text/javascript"></script>},
      javascript_include_tag('/javascripts/application')
    assert_match %r{<script src="/assets/xmlhr-[0-9a-f]+.js\?body=1" type="text/javascript"></script>\n<script src="/assets/application-[0-9a-f]+.js\?body=1" type="text/javascript"></script>},
      javascript_include_tag(:application)
  end

  test "stylesheet path through asset_path" do
    assert_match %r{/assets/application-[0-9a-f]+.css}, asset_path(:application, :ext => "css")

    assert_match %r{/assets/style-[0-9a-f]+.css}, asset_path("style", :ext => "css")
    assert_match %r{/assets/dir/style-[0-9a-f]+.css}, asset_path("dir/style.css", :ext => "css")
    assert_equal "/dir/style.css", asset_path("/dir/style.css", :ext => "css")

    assert_equal "http://www.example.com/css/style",
      asset_path("http://www.example.com/css/style", :ext => "css")
    assert_equal "http://www.example.com/css/style.css",
      asset_path("http://www.example.com/css/style.css", :ext => "css")
  end

  test "stylesheet link tag" do
    assert_match %r{<link href="/assets/application-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application)
    assert_match %r{<link href="/assets/application-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application, :digest => true)
    assert_match %r{<link href="/assets/application.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application, :digest => false)

    assert_match %r{<link href="/assets/style-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag("style")
    assert_match %r{<link href="/assets/style-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag("style.css")

    assert_equal '<link href="http://www.example.com/style.css" media="screen" rel="stylesheet" type="text/css" />',
      stylesheet_link_tag("http://www.example.com/style.css")
    assert_match %r{<link href="/assets/style-[0-9a-f]+.css" media="all" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag("style", :media => "all")
    assert_match %r{<link href="/assets/style-[0-9a-f]+.css" media="print" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag("style", :media => "print")

    assert_match %r{<link href="/assets/style-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />\n<link href="/assets/extra-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag("style", "extra")

    assert_match %r{<link href="/assets/style-[0-9a-f]+.css\?body=1" media="screen" rel="stylesheet" type="text/css" />\n<link href="/assets/application-[0-9a-f]+.css\?body=1" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application, :debug => true)

    assert_match %r{\A<link href="/assets/style-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />\Z},
      stylesheet_link_tag("style", "style")

    assert_match %r{\A<link href="/assets/style-[0-9a-f]+.ext" media="screen" rel="stylesheet" type="text/css" />\Z},
      stylesheet_link_tag("style.ext")

    assert_match %r{\A<link href="/assets/style.min-[0-9a-f]+.css" media="screen" rel="stylesheet" type="text/css" />\Z},
      stylesheet_link_tag("style.min")

    @config.assets.compile = true
    @config.assets.debug = true
    assert_match %r{<link href="/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag('/stylesheets/application')

    assert_match %r{<link href="/assets/style-[0-9a-f]+.css\?body=1" media="screen" rel="stylesheet" type="text/css" />\n<link href="/assets/application-[0-9a-f]+.css\?body=1" media="screen" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application)

    assert_match %r{<link href="/assets/style-[0-9a-f]+.css\?body=1" media="print" rel="stylesheet" type="text/css" />\n<link href="/assets/application-[0-9a-f]+.css\?body=1" media="print" rel="stylesheet" type="text/css" />},
      stylesheet_link_tag(:application, :media => "print")
  end

  test "alternate asset prefix" do
    stubs(:asset_prefix).returns("/themes/test")
    assert_match %r{/themes/test/style-[0-9a-f]+.css}, asset_path("style", :ext => "css")
  end

  test "alternate asset environment" do
    assets = Sprockets::Environment.new
    assets.append_path(FIXTURES.join("sprockets/alternate/stylesheets"))
    stubs(:asset_environment).returns(assets)
    assert_match %r{/assets/style-[0-9a-f]+.css}, asset_path("style", :ext => "css")
  end

  test "alternate hash based on environment" do
    assets = Sprockets::Environment.new
    assets.version = 'development'
    assets.append_path(FIXTURES.join("sprockets/alternate/stylesheets"))
    stubs(:asset_environment).returns(assets)
    dev_path = asset_path("style", :ext => "css")

    assets.version = 'production'
    prod_path = asset_path("style", :ext => "css")

    assert_not_equal prod_path, dev_path
  end

  test "precedence of `config.digest = false` over manifest.yml asset digests" do
    Rails.application.config.assets.digests = {'logo.png' => 'logo-d1g3st.png'}
    @config.assets.digest = false

    assert_equal '/assets/logo.png',
      asset_path("logo.png")
  end

  test "`config.digest = false` works with `config.compile = false`" do
    @config.assets.digest = false
    @config.assets.compile = false

    assert_equal '/assets/logo.png',
      asset_path("logo.png")
  end
end
