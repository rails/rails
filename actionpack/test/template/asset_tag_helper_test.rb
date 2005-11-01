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

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
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
    %(javascript_path("super/xmlhr")) => %(/javascripts/super/xmlhr.js)
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("xmlhr")) => %(<script src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("xmlhr", :lang => "vbscript")) => %(<script lang="vbscript" src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script src="/javascripts/common.javascript" type="text/javascript"></script>\n<script src="/elsewhere/cools.js" type="text/javascript"></script>),
     %(javascript_include_tag(:defaults)) => %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>)
  }

  StylePathToTag = {
    %(stylesheet_path("style")) => %(/stylesheets/style.css),
    %(stylesheet_path('dir/file')) => %(/stylesheets/dir/file.css),
    %(stylesheet_path('/dir/file')) => %(/dir/file.css)
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("style")) => %(<link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("/dir/file")) => %(<link href="/dir/file.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("dir/file")) => %(<link href="/stylesheets/dir/file.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("style", :media => "all")) => %(<link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("random.styles", "/css/stylish")) => %(<link href="/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />\n<link href="/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />)
  }

  ImagePathToTag = {
    %(image_path("xml")) => %(/images/xml.png),
  }

  ImageLinkToTag = {
    %(image_tag("xml")) => %(<img alt="Xml" src="/images/xml.png" />),
    %(image_tag("rss", :alt => "rss syndication")) => %(<img alt="rss syndication" src="/images/rss.png" />),
    %(image_tag("gold", :size => "45x70")) => %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />),
  }

  def test_auto_discovery
    AutoDiscoveryToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include
    JavascriptIncludeToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end
  
  def test_register_javascript_include_default
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'slider'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/slider.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'lib1', '/elsewhere/blub/lib2'
    assert_dom_equal  %(<script src="/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/javascripts/effects.js" type="text/javascript"></script>\n<script src="/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/javascripts/controls.js" type="text/javascript"></script>\n<script src="/javascripts/slider.js" type="text/javascript"></script>\n<script src="/javascripts/lib1.js" type="text/javascript"></script>\n<script src="/elsewhere/blub/lib2.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
  end

  def test_style_path
    StylePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_style_link
    StyleLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
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
        "http://www.example.com/calloboration/hieraki"
      end
      
    end.new
    
    @request = Class.new do 
      def relative_url_root
        "/calloboration/hieraki"
      end
    end.new
    
    @controller.request = @request
    
    ActionView::Helpers::AssetTagHelper::reset_javascript_include_default
  end

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com/calloboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com/calloboration/hieraki" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com/calloboration/hieraki" rel="alternate" title="RSS" type="application/rss+xml" />),
  }

  JavascriptPathToTag = {
    %(javascript_path("xmlhr")) => %(/calloboration/hieraki/javascripts/xmlhr.js),
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("xmlhr")) => %(<script src="/calloboration/hieraki/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script src="/calloboration/hieraki/javascripts/common.javascript" type="text/javascript"></script>\n<script src="/calloboration/hieraki/elsewhere/cools.js" type="text/javascript"></script>),
    %(javascript_include_tag(:defaults)) => %(<script src="/calloboration/hieraki/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/effects.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/controls.js" type="text/javascript"></script>)
  }

  StylePathToTag = {
    %(stylesheet_path("style")) => %(/calloboration/hieraki/stylesheets/style.css),
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("style")) => %(<link href="/calloboration/hieraki/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("random.styles", "/css/stylish")) => %(<link href="/calloboration/hieraki/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />\n<link href="/calloboration/hieraki/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />)
  }

  ImagePathToTag = {
    %(image_path("xml")) => %(/calloboration/hieraki/images/xml.png),
  }
  
  ImageLinkToTag = {
    %(image_tag("xml")) => %(<img alt="Xml" src="/calloboration/hieraki/images/xml.png" />),
    %(image_tag("rss", :alt => "rss syndication")) => %(<img alt="rss syndication" src="/calloboration/hieraki/images/rss.png" />),
    %(image_tag("gold", :size => "45x70")) => %(<img alt="Gold" height="70" src="/calloboration/hieraki/images/gold.png" width="45" />),
    %(image_tag("http://www.example.com/images/icon.gif")) => %(<img alt="Icon" src="http://www.example.com/images/icon.gif" />),
  }

  def test_auto_discovery
    AutoDiscoveryToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_javascript_include
    JavascriptIncludeToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end
  
  def test_register_javascript_include_default
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'slider'
    assert_dom_equal  %(<script src="/calloboration/hieraki/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/effects.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/controls.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/slider.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
    ActionView::Helpers::AssetTagHelper::register_javascript_include_default 'lib1', '/elsewhere/blub/lib2'
    assert_dom_equal  %(<script src="/calloboration/hieraki/javascripts/prototype.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/effects.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/dragdrop.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/controls.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/slider.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/javascripts/lib1.js" type="text/javascript"></script>\n<script src="/calloboration/hieraki/elsewhere/blub/lib2.js" type="text/javascript"></script>), javascript_include_tag(:defaults)
  end

  def test_style_path
    StylePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_style_link
    StyleLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
  end
  
  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_dom_equal(tag, eval(method)) }
    # Assigning a default alt tag should not cause an exception to be raised
    assert_nothing_raised { image_tag('') }
  end
  
  def test_stylesheet_with_asset_host_already_encoded
    ActionController::Base.asset_host = "http://foo.example.com"
    result = stylesheet_link_tag("http://bar.example.com/stylesheets/style.css")
    assert_dom_equal(
      %(<link href="http://bar.example.com/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
      result)
  ensure
    ActionController::Base.asset_host = ""
  end
  
end
