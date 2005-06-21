require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/asset_tag_helper'

class AssetTagHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper

  def setup
    @controller = Class.new do
    
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com"
      end
      
    end.new
    
    @request = Class.new do 
      def relative_url_root
        ""
      end       
    end.new
    
  end

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(nil, {}, {:type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="" type="text/html" />),
    %(auto_discovery_link_tag(nil, {}, {:title => "No stream.. really", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="No stream.. really" type="text/html" />),
    %(auto_discovery_link_tag(:rss, {}, {:title => "My RSS", :type => "text/html"})) => %(<link href="http://www.example.com" rel="alternate" title="My RSS" type="text/html" />),
    %(auto_discovery_link_tag(:atom, {}, {:rel => "Not so alternate"})) => %(<link href="http://www.example.com" rel="Not so alternate" title="ATOM" type="application/atom+xml" />),
  }

  JavascriptPathToTag = {
    %(javascript_path("xmlhr")) => %(/javascripts/xmlhr.js),
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("xmlhr")) => %(<script src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("xmlhr", :lang => "vbscript")) => %(<script lang="vbscript" src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script src="/javascripts/common.javascript" type="text/javascript"></script>\n<script src="/elsewhere/cools.js" type="text/javascript"></script>),
  }

  StylePathToTag = {
    %(stylesheet_path("style")) => %(/stylesheets/style.css),
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("style")) => %(<link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
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
    AutoDiscoveryToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_javascript_include
    JavascriptIncludeToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_style_path
    StylePathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_style_link
    StyleLinkToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end
  
end

class AssetTagHelperNonVhostTest < Test::Unit::TestCase
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::AssetTagHelper

  def setup
    @controller = Class.new do
    
      def url_for(options, *parameters_for_method_reference)
        "http://www.example.com/calloboration/hieraki"
      end
      
    end.new
    
    @request = Class.new do 
      def relative_url_root
        "/calloboration/hieraki"
      end
    end.new
    
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
    AutoDiscoveryToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_javascript_path
    JavascriptPathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_javascript_include
    JavascriptIncludeToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_style_path
    StylePathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_style_link
    StyleLinkToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_image_path
    ImagePathToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end
  
  def test_image_tag
    ImageLinkToTag.each { |method, tag| assert_equal(tag, eval(method)) }
    # Assigning a default alt tag should not cause an exception to be raised
    assert_nothing_raised { image_tag('') }
  end
  
end
