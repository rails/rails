# frozen_string_literal: true

require 'abstract_unit'
require 'stringio'

class ActionController::TestRequestTest < ActionController::TestCase
  def test_test_request_has_session_options_initialized
    assert @request.session_options
  end

  def test_mutating_session_options_does_not_affect_default_options
    @request.session_options[:myparam] = 123
    assert_nil ActionController::TestSession::DEFAULT_OPTIONS[:myparam]
  end

  def test_content_length_has_bytes_count_value
    non_ascii_parameters = { data: { content: 'Latin + Кириллица' } }
    @request.set_header 'REQUEST_METHOD', 'POST'
    @request.set_header 'CONTENT_TYPE', 'application/json'
    @request.assign_parameters(@routes, 'test', 'create', non_ascii_parameters,
                               '/test', [:data, :controller, :action])
    assert_equal(StringIO.new(non_ascii_parameters.to_json).length.to_s,
                 @request.get_header('CONTENT_LENGTH'))
  end

  ActionDispatch::Session::AbstractStore::DEFAULT_OPTIONS.each_pair do |key, value|
    test "rack default session options #{key} exists in session options and is default" do
      if value.nil?
        assert_nil(@request.session_options[key],
                   "Missing rack session default option #{key} in request.session_options")
      else
        assert_equal(value, @request.session_options[key],
                     "Missing rack session default option #{key} in request.session_options")
      end
    end

    test "rack default session options #{key} exists in session options" do
      assert(@request.session_options.has_key?(key),
                   "Missing rack session option #{key} in request.session_options")
    end
  end
end
