require File.dirname(__FILE__) + '/../../abstract_unit'

class DeprecatedBaseMethodsTest < Test::Unit::TestCase
  class Target < ActionController::Base
    def deprecated_symbol_parameter_to_url_for
      redirect_to(url_for(:home_url, "superstars"))
    end
    
    def deprecated_render_parameters
      # render ""
    end
    
    def home_url(greeting)
      "http://example.com/#{greeting}"
    end

    def rescue_action(e) raise e end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = Target.new
  end

  def test_deprecated_symbol_parameter_to_url_for
    assert_deprecated("url_for(:home_url)") do
      get :deprecated_symbol_parameter_to_url_for
    end
    assert_redirected_to "http://example.com/superstars"
  end
end
