require File.dirname(__FILE__) + '/../abstract_unit'

class UrlRewriterTests < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @params = {}
    @rewriter = ActionController::UrlRewriter.new(@request, @params)
  end 
  
  def test_simple_build_query_string
    assert_equal '?x=1&y=2', @rewriter.send(:build_query_string, :x => '1', :y => '2')
  end
  def test_convert_ints_build_query_string
    assert_equal '?x=1&y=2', @rewriter.send(:build_query_string, :x => 1, :y => 2)
  end
  def test_escape_spaces_build_query_string
    assert_equal '?x=hello+world&y=goodbye+world', @rewriter.send(:build_query_string, :x => 'hello world', :y => 'goodbye world')
  end
  def test_expand_array_build_query_string
    assert_equal '?x[]=1&x[]=2', @rewriter.send(:build_query_string, :x => [1, 2])
  end

  def test_escape_spaces_build_query_string_selected_keys
    assert_equal '?x=hello+world', @rewriter.send(:build_query_string, {:x => 'hello world', :y => 'goodbye world'}, [:x])
  end
  
end
