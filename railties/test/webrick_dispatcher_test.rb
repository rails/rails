#!/bin/env ruby

$:.unshift(File.dirname(__FILE__) + "/../lib")

require 'test/unit'
require 'webrick_server'

class ParseUriTest < Test::Unit::TestCase

  def test_parse_uri_proper_behavior
    assert_equal({:id=>"1", :controller=>"forum", :action=>"index"}, DispatchServlet.parse_uri('/forum/index/1'))
    assert_equal({:controller=>"forum", :action=>"index"}, DispatchServlet.parse_uri('/forum'))
    assert_equal({:controller=>"forum", :action=>"index"}, DispatchServlet.parse_uri('/forum/index'))
    assert_equal({:controller=>"forum", :action=>"index"}, DispatchServlet.parse_uri('/forum/'))
    assert_equal({:action=>"index", :module=>"admin", :controller=>"forum"}, DispatchServlet.parse_uri('/admin/forum/'))
  end

  def test_parse_uri_failures
    assert_equal false, DispatchServlet.parse_uri('/forum/index/1/')
    assert_equal false, DispatchServlet.parse_uri('/')
    assert_equal false, DispatchServlet.parse_uri('a')
    assert_equal false, DispatchServlet.parse_uri('/forum//')
    assert_equal false, DispatchServlet.parse_uri('/+forum/')
    assert_equal false, DispatchServlet.parse_uri('forum/')
  end

end
