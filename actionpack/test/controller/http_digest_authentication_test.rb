require 'abstract_unit'

class HttpDigestAuthenticationTest < ActionController::TestCase
  class DummyDigestController < ActionController::Base
    before_filter :authenticate, :only => :index
    before_filter :authenticate_with_request, :only => :display

    USERS = { 'lifo' => 'world', 'pretty' => 'please' }

    def index
      render :text => "Hello Secret"
    end

    def display
      render :text => 'Definitely Maybe'
    end

    private

    def authenticate
      authenticate_or_request_with_http_digest("SuperSecret") do |username|
        # Return the password
        USERS[username]
      end
    end

    def authenticate_with_request
      if authenticate_with_http_digest("SuperSecret")  { |username| USERS[username] }
        @logged_in = true
      else
        request_http_digest_authentication("SuperSecret", "Authentication Failed")
      end
    end
  end

  AUTH_HEADERS = ['HTTP_AUTHORIZATION', 'X-HTTP_AUTHORIZATION', 'X_HTTP_AUTHORIZATION', 'REDIRECT_X_HTTP_AUTHORIZATION']

  tests DummyDigestController

  AUTH_HEADERS.each do |header|
    test "successful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials(:username => 'lifo', :password => 'world')
      get :index

      assert_response :success
      assert_equal 'Hello Secret', @response.body, "Authentication failed for request header #{header}"
    end
  end

  AUTH_HEADERS.each do |header|
    test "unsuccessful authentication with #{header.downcase}" do
      @request.env[header] = encode_credentials(:username => 'h4x0r', :password => 'world')
      get :index

      assert_response :unauthorized
      assert_equal "HTTP Digest: Access denied.\n", @response.body, "Authentication didn't fail for request header #{header}"
    end
  end

  test "authentication request without credential" do
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
    credentials = decode_credentials(@response.headers['WWW-Authenticate'])
    assert_equal 'SuperSecret', credentials[:realm]
  end

  test "authentication request with invalid password" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'foo')
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
  end

  test "authentication request with invalid nonce" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please', :nonce => "xxyyzz")
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
  end

  test "authentication request with invalid opaque" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'foo', :opaque => "xxyyzz")
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
  end

  test "authentication request with invalid realm" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'foo', :realm => "NotSecret")
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
  end

  test "authentication request with valid credential" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please')
    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

   test "authentication request with relative URI" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:uri => "/", :username => 'pretty', :password => 'please')
    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  private

  def encode_credentials(options)
    options.reverse_merge!(:nc => "00000001", :cnonce => "0a4f113b")
    password = options.delete(:password)

    # Perform unautheticated get to retrieve digest parameters to use on subsequent request
    get :index

    assert_response :unauthorized

    credentials = decode_credentials(@response.headers['WWW-Authenticate'])
    credentials.merge!(options)
    credentials.reverse_merge!(:uri => "http://#{@request.host}#{@request.env['REQUEST_URI']}")
    ActionController::HttpAuthentication::Digest.encode_credentials("GET", credentials, password)
  end

  def decode_credentials(header)
    ActionController::HttpAuthentication::Digest.decode_credentials(@response.headers['WWW-Authenticate'])
  end
end