#!/bin/env ruby

$:.unshift(File.dirname(__FILE__) + "/../lib")

require 'test/unit'
require 'webrick_server'

class ParseUriTest < Test::Unit::TestCase

  def test_parse_uri_old_behavior
    assert_equal [true, 'forum', 'index', '1'], DispatchServlet.parse_uri('/forum/index/1')
    assert_equal [true, 'forum', 'index', nil], DispatchServlet.parse_uri('/forum/index')
    assert_equal [true, 'forum', 'index', nil], DispatchServlet.parse_uri('/forum/')
  end

  def test_parse_uri_new_behavior
    assert_equal [true, 'forum', 'index', '1'], DispatchServlet.parse_uri('/forum/index/1/')
    assert_equal [true, 'forum', 'index', nil], DispatchServlet.parse_uri('/forum/index/')
    assert_equal [true, 'forum', 'index', nil], DispatchServlet.parse_uri('/forum')
  end

  def test_parse_uri_failures
    assert_equal [false, nil, nil, nil], DispatchServlet.parse_uri('/')
    assert_equal [false, nil, nil, nil], DispatchServlet.parse_uri('a')
    assert_equal [false, nil, nil, nil], DispatchServlet.parse_uri('/forum//')
    assert_equal [false, nil, nil, nil], DispatchServlet.parse_uri('/+forum/')
    assert_equal [false, nil, nil, nil], DispatchServlet.parse_uri('forum/')
  end

end
