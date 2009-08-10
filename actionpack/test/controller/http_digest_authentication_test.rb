require 'abstract_unit'

class HttpDigestAuthenticationTest < ActionController::TestCase
  class DummyDigestController < ActionController::Base
    before_filter :authenticate, :only => :index
    before_filter :authenticate_with_request, :only => :display

    USERS = { 'lifo' => 'world', 'pretty' => 'please',
              'dhh' => ::Digest::MD5::hexdigest(["dhh","SuperSecret","secret"].join(":"))}

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

  setup do
    # Used as secret in generating nonce to prevent tampering of timestamp
    @old_secret, ActionController::Base.session_options[:secret] = ActionController::Base.session_options[:secret], "session_options_secret"
  end

  teardown do
    ActionController::Base.session_options[:secret] = @old_secret
  end

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

  test "authentication request with nil credentials" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => nil, :password => nil)
    get :index

    assert_response :unauthorized
    assert_equal "HTTP Digest: Access denied.\n", @response.body, "Authentication didn't fail for request"
    assert_not_equal 'Hello Secret', @response.body, "Authentication didn't fail for request"
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

  test "authentication request with valid credential and nil session" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please')

    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authentication request with request-uri that doesn't match credentials digest-uri" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please')
    @request.env['REQUEST_URI'] = "/http_digest_authentication_test/dummy_digest/altered/uri"
    get :display

    assert_response :unauthorized
    assert_equal "Authentication Failed", @response.body
  end

  test "authentication request with absolute request uri (as in webrick)" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please')
    @request.env['REQUEST_URI'] = "http://test.host/http_digest_authentication_test/dummy_digest"

    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authentication request with absolute uri in credentials (as in IE)" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:url => "http://test.host/http_digest_authentication_test/dummy_digest",
                                                            :username => 'pretty', :password => 'please')

    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authentication request with absolute uri in both request and credentials (as in Webrick with IE)" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:url => "http://test.host/http_digest_authentication_test/dummy_digest",
                                                            :username => 'pretty', :password => 'please')
    @request.env['REQUEST_URI'] = "http://test.host/http_digest_authentication_test/dummy_digest"

    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authentication request with password stored as ha1 digest hash" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'dhh',
                                           :password => ::Digest::MD5::hexdigest(["dhh","SuperSecret","secret"].join(":")),
                                           :password_is_ha1 => true)
    get :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "authentication request with _method" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => 'pretty', :password => 'please', :method => :post)
    @request.env['rack.methodoverride.original_method'] = 'POST'
    put :display

    assert_response :success
    assert assigns(:logged_in)
    assert_equal 'Definitely Maybe', @response.body
  end

  test "validate_digest_response should fail with nil returning password_procedure" do
    @request.env['HTTP_AUTHORIZATION'] = encode_credentials(:username => nil, :password => nil)
    assert !ActionController::HttpAuthentication::Digest.validate_digest_response(@request, "SuperSecret"){nil}
  end

  private

  def encode_credentials(options)
    options.reverse_merge!(:nc => "00000001", :cnonce => "0a4f113b", :password_is_ha1 => false)
    password = options.delete(:password)

    # Perform unauthenticated request to retrieve digest parameters to use on subsequent request
    method = options.delete(:method) || 'GET'

    case method.to_s.upcase
    when 'GET'
      get :index
    when 'POST'
      post :index
    end

    assert_response :unauthorized

    credentials = decode_credentials(@response.headers['WWW-Authenticate'])
    credentials.merge!(options)
    credentials.merge!(:uri => @request.env['REQUEST_URI'].to_s)
    ActionController::HttpAuthentication::Digest.encode_credentials(method, credentials, password, options[:password_is_ha1])
  end

  def decode_credentials(header)
    ActionController::HttpAuthentication::Digest.decode_credentials(@response.headers['WWW-Authenticate'])
  end
end
