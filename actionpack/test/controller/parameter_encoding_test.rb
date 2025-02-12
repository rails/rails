# frozen_string_literal: true

require "abstract_unit"

class ParameterEncodingController < ActionController::Base
  def test_undeclared_parameter
    render body: params[:foo].encoding
  end

  skip_parameter_encoding :test_skip_parameter_encoding
  def test_skip_parameter_encoding
    render body: params[:bar].encoding
  end

  param_encoding :test_param_encoding, :baz, Encoding::SHIFT_JIS
  def test_param_encoding
    render body: ::JSON.dump({ "baz" => params[:baz].encoding, "qux" => params[:qux].encoding })
  end

  skip_parameter_encoding :test_all_values_encoding
  def test_all_values_encoding
    render body: ::JSON.dump(params.except(:action, :controller).values.map(&:encoding).map(&:name))
  end
end

class ParameterEncodingTest < ActionController::TestCase
  tests ParameterEncodingController

  test "properly transcodes undeclared parameters into UTF-8 encodings" do
    post :test_undeclared_parameter, params: { "foo" => "foo" }

    assert_response :success
    assert_equal "UTF-8", @response.body
  end

  test "properly transcodes parameters of the action specified by skip_parameter_encoding to ASCII_8BIT" do
    post :test_skip_parameter_encoding, params: { "bar" => "bar" }

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end

  test "properly transcodes declared parameters into specified encodings" do
    post :test_param_encoding, params: { "baz" => "baz", "qux" => "qux" }

    assert_response :success
    assert_equal "Shift_JIS", JSON.parse(@response.body)["baz"]
    assert_equal "UTF-8", JSON.parse(@response.body)["qux"]
  end

  test "properly encodes all ASCII_8BIT parameters into binary" do
    post :test_all_values_encoding, params: { "foo" => "foo", "bar" => "bar", "baz" => "baz" }

    assert_response :success
    assert_equal ["ASCII-8BIT"], JSON.parse(@response.body).uniq
  end

  test "does not raise an error when passed a param declared as ASCII-8BIT that contains invalid bytes" do
    get :test_skip_parameter_encoding, params: { "bar" => URI::RFC2396_PARSER.escape("bar\xE2baz".b) }

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end
end
