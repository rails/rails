# frozen_string_literal: true

require "abstract_unit"

class HttpBasicAuthenticationTest < ActionController::TestCase
  class DummyController < ActionController::Base
    before_action :authenticate, only: :index
    before_action :authenticate_with_request, only: :display
    before_action :authenticate_long_credentials, only: :show
    before_action :auth_with_special_chars, only: :special_creds

    http_basic_authenticate_with name: "David", password: "Goliath", only: :search
    http_basic_authenticate_with name: "David", password: "Goliath", content_type: "application/json", only: :search_with_content_type

    def index
      render plain: "Hello Secret"
    end

    def display
      render plain: "Definitely Maybe" if @logged_in
    end

    def show
      render plain: "Only for loooooong credentials"
    end

    def special_creds
      render plain: "Only for special credentials"
    end

    def search
      render plain: "All inline"
    end

    def search_with_content_type
      render plain: "All inline"
    end

    def no_password
      username, password = authenticate_with_http_basic do |username, password|
        [username, password]
      end
      render plain: "Hello #{username} (password: #{password.inspect})"
    end

    private
      def authenticate
        authenticate_or_request_with_http_basic do |username, password|
          username == "lifo" && password == "world"
        end
      end

      def authenticate_with_request
        if authenticate_with_http_basic { |username, password| username == "pretty" && password == "please" }
          @logged_in = true
        else
          request_http_basic_authentication("SuperSecret", "Authentication Failed\n")
        end
      end

      def auth_with_special_chars
        authenticate_or_request_with_http_basic do |username, password|
          username == 'login!@#$%^&*()_+{}[];"\',./<>?`~ \n\r\t' && password == 'pwd:!@#$%^&*()_+{}[];"\',./<>?`~ \n\r\t'
        end
      end

      def authenticate_long_credentials
        authenticate_or_request_with_http_basic do |username, password|
          username == "1234567890123456789012345678901234567890" && password == "1234567890123456789012345678901234567890"
        end
      end
  end

  AUTH_HEADERS = ["HTTP_AUTHORIZATION", "X-HTTP_AUTHORIZATION", "X_HTTP_AUTHORIZATION", "REDIRECT_X_HTTP_AUTHORIZATION"]

  tests DummyController

  AUTH_HEADERS.each do |header|
    test "successful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials("lifo", "world")
      get :index

      assert_response :success
      assert_equal "Hello Secret", @response.body, "Authentication failed for request header #{header}"
    end
    test "successful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials("1234567890123456789012345678901234567890", "1234567890123456789012345678901234567890")
      get :show

      assert_response :success
      assert_equal "Only for loooooong credentials", @response.body, "Authentication failed for request header #{header} and long credentials"
    end
  end

  AUTH_HEADERS.each do |header|
    test "unsuccessful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials("h4x0r", "world")
      get :index

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header}"
    end
    test "unsuccessful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials("h4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0r", "worldworldworldworldworldworldworldworld")
      get :show

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header} and long credentials"
    end

    test "unsuccessful authentication with #{header.downcase} and no credentials" do
      get :show

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header} and no credentials"
    end
  end

  def test_encode_credentials_has_no_newline
    username = "laskjdfhalksdjfhalkjdsfhalksdjfhklsdjhalksdjfhalksdjfhlakdsjfh"
    password = "kjfhueyt9485osdfasdkljfh4lkjhakldjfhalkdsjf"
    result = ActionController::HttpAuthentication::Basic.encode_credentials(
      username, password)
    assert_no_match(/\n/, result)
  end

  test "successful authentication with uppercase authorization scheme" do
    @request.env["HTTP_AUTHORIZATION"] = "BASIC #{::Base64.encode64("lifo:world")}"
    get :index

    assert_response :success
    assert_equal "Hello Secret", @response.body, "Authentication failed when authorization scheme BASIC"
  end

  test "authentication request without credential" do
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed\n", @response.body
    assert_equal 'Basic realm="SuperSecret"', @response.headers["WWW-Authenticate"]
  end

  test "authentication request with invalid credential" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials("pretty", "foo")
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed\n", @response.body
    assert_equal 'Basic realm="SuperSecret"', @response.headers["WWW-Authenticate"]
  end

  test "authentication request with a missing password" do
    @request.env["HTTP_AUTHORIZATION"] = "Basic #{::Base64.encode64("David")}"
    get :search

    assert_response :unauthorized
  end

  test "authentication request with no required password" do
    @request.env["HTTP_AUTHORIZATION"] = "Basic #{::Base64.encode64("George")}"
    get :no_password

    assert_response :success
    assert_equal "Hello George (password: nil)", @response.body
  end

  test "authentication request with valid credential" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials("pretty", "please")
    get :display

    assert_response :success
    assert_equal "Definitely Maybe", @response.body
  end

  test "authentication request with valid credential special chars" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials('login!@#$%^&*()_+{}[];"\',./<>?`~ \n\r\t', 'pwd:!@#$%^&*()_+{}[];"\',./<>?`~ \n\r\t')
    get :special_creds

    assert_response :success
    assert_equal "Only for special credentials", @response.body
  end

  test "authenticate with class method" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials("David", "Goliath")
    get :search
    assert_response :success

    @request.env["HTTP_AUTHORIZATION"] = encode_credentials("David", "WRONG!")
    get :search
    assert_response :unauthorized
  end

  test "authentication request with wrong scheme" do
    header = "Bearer " + encode_credentials("David", "Goliath").split(" ", 2)[1]
    @request.env["HTTP_AUTHORIZATION"] = header
    get :search
    assert_response :unauthorized
  end

  test "authentication request with content_type" do
    @request.env["HTTP_AUTHORIZATION"] = encode_credentials("pretty", "please")
    get :search_with_content_type

    assert_response :unauthorized
    assert_equal "application/json", @response.media_type
  end

  private
    def encode_credentials(username, password)
      "Basic #{::Base64.encode64("#{username}:#{password}")}"
    end
end
