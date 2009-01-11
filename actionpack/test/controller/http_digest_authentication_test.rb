require 'abstract_unit'

class HttpDigestAuthenticationTest < Test::Unit::TestCase
  include ActionController::HttpAuthentication::Digest
  
  class DummyController
    attr_accessor :headers, :renders, :request, :response

    def initialize
      @headers, @renders = {}, []
      @request = ActionController::TestRequest.new
      @response = ActionController::TestResponse.new
      request.session.session_id = "test_session"
    end
    
    def render(options)
      self.renderers << options
    end
  end
  
  def setup
    @controller = DummyController.new
    @credentials = {
      :username => "dhh",
      :realm    => "testrealm@host.com",
      :nonce    => ActionController::HttpAuthentication::Digest.nonce(@controller.request),
      :qop      => "auth",
      :nc       => "00000001",
      :cnonce   => "0a4f113b",
      :opaque   => ActionController::HttpAuthentication::Digest.opaque(@controller.request),
      :uri      => "http://test.host/"
    }
    @encoded_credentials = ActionController::HttpAuthentication::Digest.encode_credentials("GET", @credentials, "secret")
  end

  def test_decode_credentials
    set_headers
    assert_equal @credentials, decode_credentials(@controller.request) 
  end 
    
  def test_nonce_format
    assert_nothing_thrown do
      validate_nonce(@controller.request, nonce(@controller.request))
    end
  end
  
  def test_authenticate_should_raise_for_nil_password
    set_headers ActionController::HttpAuthentication::Digest.encode_credentials(:get, @credentials, nil)
    assert_raise ActionController::HttpAuthentication::Error do
      authenticate(@controller, @credentials[:realm]) { |user| user == "dhh" && "secret" }
    end
  end 
  
  def test_authenticate_should_raise_for_incorrect_password 
    set_headers
    assert_raise ActionController::HttpAuthentication::Error do
      authenticate(@controller, @credentials[:realm]) { |user| user == "dhh" && "bad password" }
    end
  end 
 
  def test_authenticate_should_not_raise_for_correct_password 
    set_headers
    assert_nothing_thrown do
      authenticate(@controller, @credentials[:realm]) { |user| user == "dhh" && "secret" }
    end
  end 

  private
    def set_headers(value = @encoded_credentials, name = 'HTTP_AUTHORIZATION', method = "GET")
      @controller.request.env[name] = value
      @controller.request.env["REQUEST_METHOD"] = method
    end
end
