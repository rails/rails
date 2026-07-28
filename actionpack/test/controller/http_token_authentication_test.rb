# frozen_string_literal: true

require "abstract_unit"

class HttpTokenAuthenticationTest < ActionController::TestCase
  class DummyController < ActionController::Base
    before_action :authenticate, only: :index
    before_action :authenticate_with_request, only: :display
    before_action :authenticate_long_credentials, only: :show
    before_action :authenticate_dpop, only: :dpop
    before_action :authenticate_bearer_or_dpop, only: :bearer_or_dpop
    before_action :authenticate_private_token, only: :private_token

    def index
      render plain: "Hello Secret"
    end

    def dpop
      render plain: "Hello #{@authentication_scheme}"
    end

    def bearer_or_dpop
      render plain: "Hello #{@authentication_scheme}"
    end

    def private_token
      render plain: "Hello #{@authentication_scheme}"
    end

    def display
      render plain: "Definitely Maybe"
    end

    def show
      render plain: "Only for loooooong credentials"
    end

    private
      def authenticate
        authenticate_or_request_with_http_token do |token, _|
          token == "lifo"
        end
      end

      def authenticate_with_request
        if authenticate_with_http_token { |token, options| token == '"quote" pretty' && options[:algorithm] == "test" }
          @logged_in = true
        else
          request_http_token_authentication("SuperSecret", "Authentication Failed\n", "application/json")
        end
      end

      def authenticate_long_credentials
        authenticate_or_request_with_http_token do |token, options|
          token == "1234567890123456789012345678901234567890" && options[:algorithm] == "test"
        end
      end

      def authenticate_dpop
        authenticate_or_request_with_http_token(scheme: "DPoP") do |token, _, scheme|
          @authentication_scheme = scheme
          token == "lifo"
        end
      end

      def authenticate_bearer_or_dpop
        authenticate_or_request_with_http_token(scheme: ["Bearer", "DPoP"]) do |token, _, scheme|
          @authentication_scheme = scheme
          token == "lifo"
        end
      end

      def authenticate_private_token
        authenticate_or_request_with_http_token(scheme: "PrivateToken") do |token, _, scheme|
          @authentication_scheme = scheme
          token == "lifo"
        end
      end
  end

  AUTH_HEADERS = ["HTTP_AUTHORIZATION", "X-HTTP_AUTHORIZATION", "X_HTTP_AUTHORIZATION", "REDIRECT_X_HTTP_AUTHORIZATION"].freeze

  tests DummyController

  AUTH_HEADERS.each do |header|
    test "successful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials("lifo")
      get :index

      assert_response :success
      assert_equal "Hello Secret", @response.body, "Authentication failed for request header #{header}"
    end
    test "successful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials("1234567890123456789012345678901234567890", algorithm: "test")
      get :show

      assert_response :success
      assert_equal "Only for loooooong credentials", @response.body, "Authentication failed for request header #{header} and long credentials"
    end
  end

  AUTH_HEADERS.each do |header|
    test "unsuccessful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials("h4x0r")
      get :index

      assert_response :unauthorized
      assert_equal "HTTP Token: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header}"
    end
    test "unsuccessful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials("h4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0r")
      get :show

      assert_response :unauthorized
      assert_equal "HTTP Token: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header} and long credentials"
    end
  end

  test "authentication request with badly formatted header" do
    @request.env["HTTP_AUTHORIZATION"] = 'Token token$"lifo"'
    get :index

    assert_response :unauthorized
    assert_equal "HTTP Token: Access denied.\n", @response.body, "Authentication header was not properly parsed"
  end

  test "authentication request with evil header" do
    @request.env["HTTP_AUTHORIZATION"] = "Token ." + " " * (1024 * 80 - 8) + "."
    Timeout.timeout(1) do
      get :index
    end

    assert_response :unauthorized
    assert_equal "HTTP Token: Access denied.\n", @response.body, "Authentication header was not properly parsed"
  end

  test "successful authentication request with Bearer instead of Token" do
    @request.env["HTTP_AUTHORIZATION"] = "Bearer lifo"
    get :index

    assert_response :success
  end

  test "successful authentication request with DPoP" do
    @request.env["HTTP_AUTHORIZATION"] = "DPoP lifo"
    get :index

    assert_response :success
  end

  test "DPoP authentication request without credentials" do
    get :dpop

    assert_response :unauthorized
    assert_equal 'DPoP realm="Application"', @response.headers["WWW-Authenticate"]
  end

  test "authentication can be restricted to DPoP" do
    @request.env["HTTP_AUTHORIZATION"] = "Bearer lifo"
    get :dpop

    assert_response :unauthorized
    assert_equal 'DPoP realm="Application"', @response.headers["WWW-Authenticate"]
  end

  test "successful authentication when restricted to DPoP" do
    @request.env["HTTP_AUTHORIZATION"] = "DPoP lifo"
    get :dpop

    assert_response :success
    assert_equal "Hello dpop", @response.body
  end

  test "authentication can be restricted to multiple schemes" do
    @request.env["HTTP_AUTHORIZATION"] = "Token lifo"
    get :bearer_or_dpop

    assert_response :unauthorized
    assert_equal 'Bearer realm="Application", DPoP realm="Application"', @response.headers["WWW-Authenticate"]
  end

  test "successful authentication with any of multiple schemes" do
    @request.env["HTTP_AUTHORIZATION"] = "Bearer lifo"
    get :bearer_or_dpop

    assert_response :success
    assert_equal "Hello bearer", @response.body

    @request.env["HTTP_AUTHORIZATION"] = "DPoP lifo"
    get :bearer_or_dpop

    assert_response :success
    assert_equal "Hello dpop", @response.body
  end

  test "successful authentication request with case-insensitive scheme" do
    ["bearer lifo", "BEARER lifo", "token lifo", "TOKEN lifo", "dpop lifo", "DPOP lifo"].each do |header|
      @request.env["HTTP_AUTHORIZATION"] = header
      get :index

      assert_response :success, "expected #{header.inspect} to authenticate"
    end
  end

  test "authentication request with tab in header" do
    @request.env["HTTP_AUTHORIZATION"] = "Token\ttoken=\"lifo\""
    get :index

    assert_response :success
    assert_equal "Hello Secret", @response.body
  end

  test "authentication request without credential" do
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed\n", @response.body
    assert_equal "application/json", @response.media_type
    assert_equal 'Token realm="SuperSecret"', @response.headers["WWW-Authenticate"]
  end

  test "authentication request with invalid credential" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials('"quote" pretty')
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed\n", @response.body
    assert_equal "application/json", @response.media_type
    assert_equal 'Token realm="SuperSecret"', @response.headers["WWW-Authenticate"]
  end

  test "authenticate ignores the scheme argument for two-parameter blocks" do
    controller = Struct.new(:request).new(sample_request("token"))

    result = ActionController::HttpAuthentication::Token.authenticate(controller) { |token, options| token }

    assert_equal "token", result
  end

  test "authentication rejects unknown schemes by default" do
    @request.env["HTTP_AUTHORIZATION"] = "Basic lifo"
    get :index

    assert_response :unauthorized
  end

  test "authentication can require a custom scheme" do
    @request.env["HTTP_AUTHORIZATION"] = "PrivateToken lifo"
    get :private_token

    assert_response :success
    assert_equal "Hello privatetoken", @response.body
  end

  test "custom scheme challenge uses the scheme name verbatim" do
    get :private_token

    assert_response :unauthorized
    assert_equal 'PrivateToken realm="Application"', @response.headers["WWW-Authenticate"]
  end

  test "token_and_options returns correct token" do
    token = "rcHu+HzSFw89Ypyhn/896A=="
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token)).first
    expected = token
    assert_equal(expected, actual)
  end

  test "token_and_options returns correct token with value after the equal sign" do
    token = "rcHu+=HzSFw89Ypyhn/896A==f34"
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token)).first
    expected = token
    assert_equal(expected, actual)
  end

  test "token_and_options returns correct token with slashes" do
    token = 'rcHu+\\\\"/896A'
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token)).first
    expected = token
    assert_equal(expected, actual)
  end

  test "token_and_options returns correct token with quotes" do
    token = '\"quote\" pretty'
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token)).first
    expected = token
    assert_equal(expected, actual)
  end

  test "token_and_options returns empty string with empty token" do
    token = +""
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token)).first
    expected = token
    assert_equal(expected, actual)
  end

  test "token_and_options returns correct token with nonce option" do
    token = "rcHu+HzSFw89Ypyhn/896A="
    nonce_hash = { nonce: "123abc" }
    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token, nonce_hash))
    expected_token = token
    expected_nonce = { "nonce" => nonce_hash[:nonce] }
    assert_equal(expected_token, actual.first)
    assert_equal(expected_nonce, actual.last)
  end

  test "token_and_options returns nil with no value after the equal sign" do
    actual = ActionController::HttpAuthentication::Token.token_and_options(malformed_request).first
    assert_nil actual
  end

  test "token_and_options ignores empty elements in header value" do
    token = "foo,,bar,  ,   , baz=qux"
    expected_token = "foo"
    expected_options = { "bar" => nil, "baz" => "qux" }

    actual = ActionController::HttpAuthentication::Token.token_and_options(sample_request(token, {}))
    assert_equal expected_token, actual.first
    assert_equal expected_options, actual.last
  end

  test "raw_params returns a tuple of two key value pair strings" do
    auth = sample_request("rcHu+HzSFw89Ypyhn/896A=").authorization.to_s
    actual = ActionController::HttpAuthentication::Token.raw_params(auth)
    expected = ["token=\"rcHu+HzSFw89Ypyhn/896A=\"", "nonce=\"def\""]
    assert_equal(expected, actual)
  end

  test "raw_params returns a tuple of key value pair strings when auth does not contain a token key" do
    auth = sample_request_without_token_key("rcHu+HzSFw89Ypyhn/896A=").authorization.to_s
    actual = ActionController::HttpAuthentication::Token.raw_params(auth)
    expected = ["token=rcHu+HzSFw89Ypyhn/896A="]
    assert_equal(expected, actual)
  end

  test "raw_params returns a tuple of key strings when auth does not contain a token key and value" do
    auth = sample_request_without_token_key(nil).authorization.to_s
    actual = ActionController::HttpAuthentication::Token.raw_params(auth)
    expected = ["token="]
    assert_equal(expected, actual)
  end

  test "token_and_options returns right token when token key is not specified in header" do
    token = "rcHu+HzSFw89Ypyhn/896A="

    actual = ActionController::HttpAuthentication::Token.token_and_options(
      sample_request_without_token_key(token)
    ).first

    expected = token
    assert_equal(expected, actual)
  end

  private
    def sample_request(token, options = { nonce: "def" })
      authorization = options.inject([%{Token token="#{token}"}]) do |arr, (k, v)|
        arr << "#{k}=\"#{v}\""
      end.join(", ")
      mock_authorization_request(authorization)
    end

    def malformed_request
      mock_authorization_request(%{Token token=})
    end

    def sample_request_without_token_key(token)
      mock_authorization_request(%{Token #{token}})
    end

    def mock_authorization_request(authorization)
      Struct.new(:authorization).new(authorization)
    end

    def encode_credentials(token, options = {})
      ActionController::HttpAuthentication::Token.encode_credentials(token, options)
    end
end
