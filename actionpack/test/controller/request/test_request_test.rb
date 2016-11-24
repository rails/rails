require "abstract_unit"
require "stringio"

class ActionController::TestRequestTest < ActionController::TestCase
  def test_test_request_has_session_options_initialized
    assert @request.session_options
  end

  def test_mutating_session_options_does_not_affect_default_options
    @request.session_options[:myparam] = 123
    assert_equal nil, ActionController::TestSession::DEFAULT_OPTIONS[:myparam]
  end

  def test_content_length_has_bytes_count_value
    non_ascii_parameters = { data: { content: "Latin + Кириллица" } }
    @request.set_header "REQUEST_METHOD", "POST"
    @request.set_header "CONTENT_TYPE", "application/json"
    @request.assign_parameters(@routes, "test", "create", non_ascii_parameters,
                               "/test", [:data, :controller, :action])
    assert_equal(@request.get_header("CONTENT_LENGTH"),
                 StringIO.new(non_ascii_parameters.to_json).length.to_s)
  end

  ActionDispatch::Session::AbstractStore::DEFAULT_OPTIONS.each_key do |option|
    test "rack default session options #{option} exists in session options and is default" do
      assert_equal(ActionDispatch::Session::AbstractStore::DEFAULT_OPTIONS[option],
                   @request.session_options[option],
                   "Missing rack session default option #{option} in request.session_options")
    end

    test "rack default session options #{option} exists in session options" do
      assert(@request.session_options.has_key?(option),
                   "Missing rack session option #{option} in request.session_options")
    end
  end
end
