require 'abstract_unit'

class HttpBasicAuthenticationTest < Test::Unit::TestCase
  include ActionController::HttpAuthentication::Basic
  
  class DummyController
    attr_accessor :headers, :renders, :request
    
    def initialize
      @headers, @renders = {}, []
      @request = ActionController::TestRequest.new
    end
    
    def render(options)
      self.renders << options
    end
  end

  def setup
    @controller  = DummyController.new
    @credentials = ActionController::HttpAuthentication::Basic.encode_credentials("dhh", "secret")
  end

  def test_successful_authentication
    login = Proc.new { |user_name, password| user_name == "dhh" && password == "secret" }
    set_headers
    assert authenticate(@controller, &login)

    set_headers ''
    assert_nothing_raised do
      assert !authenticate(@controller, &login)
    end

    set_headers nil
    set_headers @credentials, 'REDIRECT_X_HTTP_AUTHORIZATION'
    assert authenticate(@controller, &login)
  end

  def test_failing_authentication
    set_headers
    assert !authenticate(@controller) { |user_name, password| user_name == "dhh" && password == "incorrect" }
  end
  
  def test_authentication_request
    authentication_request(@controller, "Megaglobalapp")
    assert_equal 'Basic realm="Megaglobalapp"', @controller.headers["WWW-Authenticate"]
    assert_equal :unauthorized, @controller.renders.first[:status]
  end

  private
    def set_headers(value = @credentials, name = 'HTTP_AUTHORIZATION')
      @controller.request.env[name] = value
    end
end
