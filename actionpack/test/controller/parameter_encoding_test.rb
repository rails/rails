require "abstract_unit"

class ParameterEncodingController < ActionController::Base
  parameter_encoding :test_bar,          :bar, Encoding::ASCII_8BIT
  parameter_encoding :test_baz,          :baz, Encoding::ISO_8859_1
  parameter_encoding :test_baz_to_ascii, :baz, Encoding::ASCII_8BIT

  def test_foo
    render body: params[:foo].encoding
  end

  def test_bar
    render body: params[:bar].encoding
  end

  def test_baz
    render body: params[:baz].encoding
  end

  def test_no_change_to_baz
    render body: params[:baz].encoding
  end

  def test_baz_to_ascii
    render body: params[:baz].encoding
  end
end

class ParameterEncodingTest < ActionController::TestCase
  tests ParameterEncodingController

  test "properly transcodes UTF8 parameters into declared encodings" do
    post :test_foo, params: {"foo" => "foo", "bar" => "bar", "baz" => "baz"}

    assert_response :success
    assert_equal "UTF-8", @response.body
  end

  test "properly transcodes ASCII_8BIT parameters into declared encodings" do
    post :test_bar, params: {"foo" => "foo", "bar" => "bar", "baz" => "baz"}

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end

  test "properly transcodes ISO_8859_1 parameters into declared encodings" do
    post :test_baz, params: {"foo" => "foo", "bar" => "bar", "baz" => "baz"}

    assert_response :success
    assert_equal "ISO-8859-1", @response.body
  end

  test "does not transcode parameters when not specified" do
    post :test_no_change_to_baz, params: {"foo" => "foo", "bar" => "bar", "baz" => "baz"}

    assert_response :success
    assert_equal "UTF-8", @response.body
  end

  test "respects different encoding declarations for a param per action" do
    post :test_baz_to_ascii, params: {"foo" => "foo", "bar" => "bar", "baz" => "baz"}

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end

  test "does not raise an error when passed a param declared as ASCII-8BIT that contains invalid bytes" do
    get :test_bar, params: { "bar" => URI.parser.escape("bar\xE2baz".b) }

    assert_response :success
    assert_equal "ASCII-8BIT", @response.body
  end
end
