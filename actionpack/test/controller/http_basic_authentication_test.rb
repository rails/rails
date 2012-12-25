require 'abstract_unit'

class HttpBasicAuthenticationTest < ActionController::TestCase
  class DummyController < ActionController::Base
    before_action :authenticate, only: :index
    before_action :authenticate_with_request, only: :display
    before_action :authenticate_long_credentials, only: :show

    http_basic_authenticate_with :name => "David", :password => "Goliath", :only => :search

    def index
      render :text => "Hello Secret"
    end

    def display
      render :text => 'Definitely Maybe'
    end

    def show
      render :text => 'Only for loooooong credentials'
    end

    def search
      render :text => 'All inline'
    end

    private

    def authenticate
      authenticate_or_request_with_http_basic do |username, password|
        username == 'lifo' && password == 'world'
      end
    end

    def authenticate_with_request
      if authenticate_with_http_basic { |username, password| username == 'pretty' && password == 'please' }
        @logged_in = true
      else
        request_http_basic_authentication("SuperSecret")
      end
    end

    def authenticate_long_credentials
      authenticate_or_request_with_http_basic do |username, password|
        username == '1234567890123456789012345678901234567890' && password == '1234567890123456789012345678901234567890'
      end
    end
  end

  AUTH_HEADERS = ['HTTP_AUTHORIZATION', 'X-HTTP_AUTHORIZATION', 'X_HTTP_AUTHORIZATION', 'REDIRECT_X_HTTP_AUTHORIZATION']

  tests DummyController

  AUTH_HEADERS.each do |header|
    test "successful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials('lifo', 'world')
      get :index

      assert_response :success
      assert_equal 'Hello Secret', @response.body, "Authentication failed for request header #{header}"
    end
    test "successful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials('1234567890123456789012345678901234567890', '1234567890123456789012345678901234567890')
      get :show

      assert_response :success
      assert_equal 'Only for loooooong credentials', @response.body, "Authentication failed for request header #{header} and long credentials"
    end
  end

  AUTH_HEADERS.each do |header|
    test "unsuccessful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials('h4x0r', 'world')
      get :index

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header}"
    end
    test "unsuccessful authentication with #{header.downcase} and long credentials" do
      @request.env[header] = encode_credentials('h4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0rh4x0r', 'worldworldworldworldworldworldworldworld')
      get :show

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header} and long credentials"
    end
  end

  def test_encode_credentials_has_no_newline
    username = 'laskjdfhalksdjfhalkjdsfhalksdjfhklsdjhalksdjfhalksdjfhlakdsjfh'
    password = 'kjfhueyt9485osdfasdkljfh4lkjhakldjfhalkdsjf'
    result = ActionController::HttpAuthentication::Basic.encode_credentials(
      username, password)
    assert_no_match(/\n/, result)
  end

  test "authentication request without credential" do
    get :display

    assert_response :unauthorized
    assert_equal "HTTP Basic: Access denied.\n", @response.body
    assert_equal 'Basic realm="SuperSecret"', @response.headers['WWW-Authenticate']
  end

  test "authentication request with invalid credential" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials('pretty', 'foo')
    get :display

    assert_response :unauthorized
    assert_equal "HTTP Basic: Access denied.\n", @response.body
    assert_equal 'Basic realm="SuperSecret"', @response.headers['WWW-Authenticate']
  end

  test "authentication request with valid credential" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials('pretty', 'please')
    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authenticate with class method" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials('David', 'Goliath')
    get :search
    assert_response :success

    @request.env['HTTP_AUTHORIZATION'] = encode_credentials('David', 'WRONG!')
    get :search
    assert_response :unauthorized
  end

  private

  def encode_credentials(username, password)
    "Basic #{::Base64.encode64("#{username}:#{password}")}"
  end
end
