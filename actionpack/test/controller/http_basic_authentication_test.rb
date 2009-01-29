require 'abstract_unit'

class HttpBasicAuthenticationTest < ActionController::TestCase
  class DummyController < ActionController::Base
    before_filter :authenticate, :only => :index
    before_filter :authenticate_with_request, :only => :display

    def index
      render :text => "Hello Secret"
    end

    def display
      render :text => 'Definitely Maybe'
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
  end

  AUTH_HEADERS.each do |header|
    test "unsuccessful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials('h4x0r', 'world')
      get :index

      assert_response :unauthorized
      assert_equal "HTTP Basic: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header}"
    end
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

  private

  def encode_credentials(username, password)
    "Basic #{ActiveSupport::Base64.encode64("#{username}:#{password}")}"
  end
end
