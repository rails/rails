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
    end
    @controller = @controller.new
  end

  AutoDiscoveryToTag = {
    %(auto_discovery_link_tag) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
    %(auto_discovery_link_tag(:atom)) => %(<link href="http://www.example.com" rel="alternate" title="ATOM" type="application/atom+xml" />),
    %(auto_discovery_link_tag(:rss, :action => "feed")) => %(<link href="http://www.example.com" rel="alternate" title="RSS" type="application/rss+xml" />),
  }

  JavascriptIncludeToTag = {
    %(javascript_include_tag("xmlhr")) => %(<script language="JavaScript" src="/javascripts/xmlhr.js" type="text/javascript"></script>),
    %(javascript_include_tag("common.javascript", "/elsewhere/cools")) => %(<script language="JavaScript" src="/javascripts/common.javascript" type="text/javascript"></script>\n<script language="JavaScript" src="/elsewhere/cools.js" type="text/javascript"></script>),
  }

  StyleLinkToTag = {
    %(stylesheet_link_tag("style")) => %(<link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />),
    %(stylesheet_link_tag("random.styles", "/css/stylish")) => %(<link href="/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />\n<link href="/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />)
  }

  def test_auto_discovery
    AutoDiscoveryToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_javascript_include
    JavascriptIncludeToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_style_link
    StyleLinkToTag.each { |method, tag| assert_equal(tag, eval(method)) }
  end

  def test_image_tag
    assert_equal %(<img alt="Gold" height="70" src="/images/gold.png" width="45" />), image_tag("gold", :size => "45x70")
  end
end