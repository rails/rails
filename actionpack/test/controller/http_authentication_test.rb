require File.dirname(__FILE__) + '/../abstract_unit'

class HttpBasicAuthenticationTest < Test::Unit::TestCase
  include ActionController::HttpAuthentication::Basic
  
  def setup
    @controller = Class.new do
      attr_accessor :headers, :renders
      
      def initialize
        @headers, @renders = {}, []
      end
      
      def request
        Class.new do
          def env
            { 'HTTP_AUTHORIZATION' => ActionController::HttpAuthentication::Basic.encode_credentials("dhh", "secret") }
          end
        end.new
      end
      
      def render(options)
        self.renders << options
      end
    end.new
  end

  def test_successful_authentication
    assert authenticate(@controller) { |user_name, password| user_name == "dhh" && password == "secret" }
  end


  def test_failing_authentication
    assert !authenticate(@controller) { |user_name, password| user_name == "dhh" && password == "secret!!" }
  end
  
  def test_authentication_request
    authentication_request(@controller, "Megaglobalapp")
    assert_equal 'Basic realm="Megaglobalapp"', @controller.headers["WWW-Authenticate"]
    assert_equal :unauthorized, @controller.renders.first[:status]
  end
end
