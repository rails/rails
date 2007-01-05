require File.dirname(__FILE__) + '/../abstract_unit'

class AssetTagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper

  def setup
    @controller = Class.new do

      attr_accessor :request
    
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com"
      end
      
    end.new
    
    @request = Class.new do 
      def relative_url_root
        ""
      end       
    end.new

    @controller.request = @request
    
    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  def teardown
    Object.send(:remove_const, :RAILS_ROOT) if defined?(RAILS_ROOT)
    ENV["RAILS_ASSET_ID"] = nil
  end

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss)) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, "http://localhost/feed")) => %(<link href="http://localhost/feed" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(nil, {}, {:type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="" type="text/html" />),
    %(auto_discovery_link_tag(nil, {}, {:title => "No stream.. really", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="No stream.. really" type="text/html" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="text/html" />),
    %(auto_discovery_link_tag(:atom, {}, {:rel => "Not so alternate"})) => %(<link href="http://www.example.com" rel="Not so alternate" title="ATOM" type="application/atom+xml" />),
  }

  JavascriptPathToTag = {
    %(javascript_path("xmlhr")) => %(/javascripts/xmlhr.js),
    %(javascript_path("super/xmlhr")) => %(/javascripts/super/xmlhr.js),
    %(javascript_path("/super/xmlhr.js")) => %(/super/xmlhr.js)
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("xmlhr")) => %(<script src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("xmlhr.js")) => %(<script src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("xmlhr", :lang => "vbscript")) => %(<script lang="vbscript" src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script src="/javascripts/common.javascript" type="text/javascript"></script>\n<script src="/elsewhere/cools.js" type="text/javascript"></script>),
    %(javascript_include_tag(:defaults)) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>),
    %(javascript_include_tag(:defaults, "test")) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/test.js" type="text/javascript"></script>),
    %(javascript_include_tag("test", :defaults)) => %(<script src="/javascripts/test.js" type="text/javascript"></script>\n<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>)
  }

  StylePathToTag = {
    %(stylesheet_path("style")) => %(/stylesheets/style.css),
    %(stylesheet_path("style.css")) => %(/stylesheets/style.css),
    %(stylesheet_path('dir/file')) => %(/stylesheets/dir/file.css),
    %(stylesheet_path('/dir/file.rcss')) => %(/dir/file.rcss)
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("style")) => %(<link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("style.css")) => %(<link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("/dir/file")) => %(<link href="/dir/file.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("dir/file")) => %(<link href="/stylesheets/dir/file.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("style", :media => "all")) => %(<link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("random.styles", "/css/stylish")) => %(<link href="/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />\n<link href="/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("http://www.example.com/styles/style")) => %(<link href="http://www.example.com/styles/style.css" media="screen" rel="Stylesheet" type="text/css" />)
  }

  ImagePathToTag = {
    %(image_path("xml.png")) => %(/images/xml.png),
    %(image_path("dir/xml.png")) => %(/images/dir/xml.png),
    %(image_path("/dir/xml.png")) => %(/dir/xml.png)    
  }

  ImageLinkToTag = {
    %(image_tag("xml.png")) => %(<img alt="Xml" src="/images/xml.png" />),
    %(image_tag("rss.gif", :alt => "rss syndication")) => %(<img alt="rss syndication" src="/images/rss.gif" />),
    %(image_tag("gold.png", :size => "45x70")) => %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />),
    %(image_tag("gold.png", "size" => "45x70")) => %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />),
    %(image_tag("error.png", "size" => "45")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("error.png", "size" => "45 x 70")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("error.png", "size" => "x")) => %(<img alt="Error" src="/images/error.png" />),
    %(image_tag("http://www.rubyonrails.com/images/rails.png")) => %(<img alt="Rails" src="http://www.rubyonrails.com/images/rails.png" />)
  }

  DeprecatedImagePathToTag = {
    %(image_path("xml")) => %(/images/xml.png)
  }


  def test_auto_discovery_link_tag
    AutoDiscoveryToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include_tag
    JavascriptIncludeToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
    
    Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + "/../fixtures/")
    ENV["RAILS_ASSET_ID"] = "1"    
    assert_dom_equal(%(<script src="/javascripts/prototype.js?1" type="text/javascript"></script>\n<script src="/javascripts/effects.js?1" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js?1" type="text/javascript"></script>\n<script src="/javascripts/controls.js?1" type="text/javascript"></script>\n<script src="/javascripts/application.js?1" type="text/javascript"></script>), javascript_include_tag(:defaults))
  end
  
  def test_register_javascript_include_default
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'slider'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/slider.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'lib1', '/elsewhere/blub/lib2'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/slider.js" type="text/javascript"></script>\n<script src="/javascripts/lib1.js" type="text/javascript"></script>\n<script src="/elsewhere/blub/lib2.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
  end
  
  def test_stylesheet_path
    StylePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_stylesheet_link_tag
    StyleLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end
  
  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end
  
  def test_should_deprecate_image_filename_with_no_extension
    DeprecatedImagePathToTag.each do |method, tag| 
      assert_deprecated("image_path") { assert_dom_equal(tag, eval(method)) }
    end
  end
  
  def test_timebased_asset_id
    Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + "/../fixtures/")
    expected_time = File.stat(File.expand_path(File.dirname(__FILE__) + "/../fixtures/public/images/rails.png")).mtime.to_i.to_s
    assert_equal %(<img alt="Rails" src="/images/rails.png?#{expected_time}" />), image_tag("rails.png")
  end

  def test_should_skip_asset_id_on_complete_url
    Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + "/../fixtures/")
    assert_equal %(<img alt="Rails" src="http://www.example.com/rails.png" />), image_tag("http://www.example.com/rails.png")
  end
  
  def test_should_use_preset_asset_id
    Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + "/../fixtures/")
    ENV["RAILS_ASSET_ID"] = "4500"
    assert_equal %(<img alt="Rails" src="/images/rails.png?4500" />), image_tag("rails.png")
  end

  def test_preset_empty_asset_id
    Object.send(:const_set, :RAILS_ROOT, File.dirname(__FILE__) + "/../fixtures/")
    ENV["RAILS_ASSET_ID"] = ""
    assert_equal %(<img alt="Rails" src="/images/rails.png" />), image_tag("rails.png")
  end

  def test_should_not_modify_source_string
    source = '/images/rails.png'
    copy = source.dup
    image_tag(source)
    assert_equal copy, source
  end
end

class AssetTagHelperNonVhostTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper

  def setup
    @controller = Class.new do
      attr_accessor :request

      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com/collaboration/hieraki"
      end
    end.new
    
    @request = Class.new do 
      def relative_url_root
        "/collaboration/hieraki"
      end
    end.new
    
    @controller.request = @request
    
    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  def test_should_compute_proper_path
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(/collaboration/hieraki/images/xml.png), image_path("xml.png"))
  end
  
  def test_should_ignore_relative_root_path_on_complete_url
    assert_dom_equal(%(http://www.example.com/images/xml.png), image_path("http://www.example.com/images/xml.png"))
  end

  def test_should_compute_proper_path_with_asset_host
    ActionController::Base.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="http://www.example.com/collaboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />), auto_discovery_link_tag)
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/javascripts/xmlhr.js), javascript_path("xmlhr"))
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/stylesheets/style.css), stylesheet_path("style"))
    assert_dom_equal(%(http://assets.example.com/collaboration/hieraki/images/xml.png), image_path("xml.png"))
  ensure
    ActionController::Base.asset_host = ""
  end

  def test_should_ignore_asset_host_on_complete_url
    ActionController::Base.asset_host = "http://assets.example.com"
    assert_dom_equal(%(<link href="http://bar.example.com/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />), stylesheet_link_tag("http://bar.example.com/stylesheets/style.css"))
  ensure
    ActionController::Base.asset_host = ""
  end
end
