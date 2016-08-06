require "abstract_unit"
require "active_support/logger"

class CaptureController < ActionController::Base
  self.view_paths = [ File.dirname(__FILE__) + "/../../fixtures/actionpack" ]

  def self.controller_name; "test"; end
  def self.controller_path; "test"; end

  def content_for
    @title = nil
    render :layout => "talk_from_action"
  end

  def content_for_with_parameter
    @title = nil
    render :layout => "talk_from_action"
  end

  def content_for_concatenated
    @title = nil
    render :layout => "talk_from_action"
  end

  def non_erb_block_content_for
    @title = nil
    render :layout => "talk_from_action"
  end

  def proper_block_detection
    @todo = "some todo"
  end
end

class CaptureTest < ActionController::TestCase
  tests CaptureController

  def setup
    super
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = ActiveSupport::Logger.new(nil)

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

  def test_should_concatenate_content_for
    get :content_for_concatenated
    assert_equal expected_content_for_output, @response.body
  end

  def test_should_set_content_for_with_parameter
    get :content_for_with_parameter
    assert_equal expected_content_for_output, @response.body
  end

  def test_non_erb_block_content_for
    get :non_erb_block_content_for
    assert_equal expected_content_for_output, @response.body
  end

  def test_proper_block_detection
    get :proper_block_detection
    assert_equal "some todo", @response.body
  end

  private
    def expected_content_for_output
      "<title>Putting stuff in the title!</title>\nGreat stuff!"
    end
end
