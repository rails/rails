require 'abstract_unit'
require 'stringio'

class ActionController::TestRequestTest < ActiveSupport::TestCase

  def setup
    @request = ActionController::TestRequest.new
  end

  def test_test_request_has_session_options_initialized
    assert @request.session_options
  end
  
  Rack::Session::Abstract::ID::DEFAULT_OPTIONS.each_key do |option|
    test "test_rack_default_session_options_#{option}_exists_in_session_options_and_is_default" do
      assert_equal(Rack::Session::Abstract::ID::DEFAULT_OPTIONS[option], 
                   @request.session_options[option], 
                   "Missing rack session default option #{option} in request.session_options")
    end
    test "test_rack_default_session_options_#{option}_exists_in_session_options" do
      assert(@request.session_options.has_key?(option), 
                   "Missing rack session option #{option} in request.session_options")
    end
  end
  
  def test_session_id_exists_by_default
    assert_not_nil(@request.session_options[:id])
  end
  
  def test_session_id_different_on_each_call
    prev_id = 
    assert_not_equal(@request.session_options[:id], ActionController::TestRequest.new.session_options[:id])
  end
  
end