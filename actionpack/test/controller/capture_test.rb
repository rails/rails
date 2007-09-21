require File.dirname(__FILE__) + '/../abstract_unit'

class CaptureController < ActionController::Base
  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  def content_for
    render :layout => "talk_from_action"
  end

  def content_for_with_parameter
    render :layout => "talk_from_action"
  end
  
  def content_for_concatenated
    render :layout => "talk_from_action"
  end

  def erb_content_for
    render :layout => "talk_from_action"
  end

  def block_content_for
    render :layout => "talk_from_action"
  end

  def non_erb_block_content_for
    render :layout => "talk_from_action"
  end

  def rescue_action(e) raise end
end

CaptureController.view_paths = [ File.dirname(__FILE__) + "/../fixtures/" ]

class CaptureTest < Test::Unit::TestCase
  def setup
    @controller = CaptureController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.host = "www.nextangle.com"
  end

  def test_simple_capture
    get :capturing
    assert_equal "Dreamy days", @response.body.strip
  end

  def test_content_for
    get :content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_should_concatentate_content_for
    get :content_for_concatenated
    assert_equal expected_content_for_output, @response.body
  end

  def test_erb_content_for
    get :erb_content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_should_set_content_for_with_parameter
    get :content_for_with_parameter
    assert_equal expected_content_for_output, @response.body
  end

  def test_block_content_for
    get :block_content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_non_erb_block_content_for
    get :non_erb_block_content_for
    assert_equal expected_content_for_output, @response.body
  end

  private
    def expected_content_for_output
      "<title>Putting stuff in the title!</title>\n\nGreat stuff!"
    end
end
