# frozen_string_literal: true

require "abstract_unit"

class ParameterEncodingController < ActionController::Base
  skip_parameter_encoding :test_bar
  skip_parameter_encoding :test_all_values_encoding

  def test_foo
    render body: params[:foo].encoding
  end

  def test_bar
    render body: params[:bar].encoding
  end

  def test_all_values_encoding
    render body: ::JSON.dump(params.values.map(&:encoding).map(&:name))
  end
end

class ParameterEncodingTest < ActionController::TestCase
  tests ParameterEncodingController

  test "properly transcodes UTF8 parameters into declared encodings" do
    post :test_foo, params: { "foo" => "foo", "bar" => "bar", "baz" => "baz" }

    assert_response :success
    assert_equal "UTF-8", @response.body
  end

  test "properly encodes ASCII_8BIT parameters into binary" do
    post :test_bar, params: { "foo" => "foo", "bar" => "bar", "baz" => "baz" }

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end

  test "properly encodes all ASCII_8BIT parameters into binary" do
    post :test_all_values_encoding, params: { "foo" => "foo", "bar" => "bar", "baz" => "baz" }

    assert_response :success
    assert_equal ["ASCII-8BIT"], JSON.parse(@response.body).uniq
  end

  test "does not raise an error when passed a param declared as ASCII-8BIT that contains invalid bytes" do
    get :test_bar, params: { "bar" => URI::DEFAULT_PARSER.escape("bar\xE2baz".b) }

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end
end
