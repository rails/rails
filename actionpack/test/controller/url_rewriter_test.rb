require File.dirname(__FILE__) + '/../abstract_unit'

class UrlRewriterTests < Test::Unit::TestCase
  def setup
    @request = ActionController::TestRequest.new
    @params = {}
    @rewriter = ActionController::UrlRewriter.new(@request, @params)
  end 

  def test_overwrite_params
    @params[:controller] = 'hi'
    @params[:action] = 'bye'
    @params[:id] = '2'

    assert_equal '/hi/hi/2', @rewriter.rewrite(:only_path => true, :overwrite_params => {:action => 'hi'})
    u = @rewriter.rewrite(:only_path => false, :overwrite_params => {:action => 'hi'})
    assert_match %r(/hi/hi/2$), u
  end
  

  private
    def split_query_string(str)
      [str[0].chr] + str[1..-1].split(/&/).sort
    end
  
    def assert_query_equal(q1, q2)
      assert_equal(split_query_string(q1), split_query_string(q2))
    end
end
