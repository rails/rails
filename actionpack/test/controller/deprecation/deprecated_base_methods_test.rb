require 'abstract_unit'

class DeprecatedBaseMethodsTest < Test::Unit::TestCase
  class Target < ActionController::Base
    def home_url(greeting)
      "http://example.com/#{greeting}"
    end

    def raises_name_error
      this_method_doesnt_exist
    end

    def rescue_action(e) raise e end
  end

  def setup
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller = Target.new
  end

  def test_log_error_silences_deprecation_warnings
    get :raises_name_error
  rescue => e
    assert_not_deprecated { @controller.send :log_error, e }
  end

  def test_assertion_failed_error_silences_deprecation_warnings
    get :raises_name_error
  rescue => e
    error = Test::Unit::Error.new('testing ur doodz', e)
    assert_not_deprecated { error.message }
  end
end
