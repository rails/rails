require 'abstract_unit'

class ShowExceptionsTest < ActionDispatch::IntegrationTest

  class Boomer
    def initialize(detailed  = false)
      @detailed = detailed
    end

    def call(env)
      env['action_dispatch.show_detailed_exceptions'] = @detailed
      req = ActionDispatch::Request.new(env)
      case req.path
      when "/not_found"
        raise ActionController::UnknownAction
      when "/runtime_error"
        raise RuntimeError
      when "/method_not_allowed"
        raise ActionController::MethodNotAllowed
      when "/not_implemented"
        raise ActionController::NotImplemented
      when "/unprocessable_entity"
        raise ActionController::InvalidAuthenticityToken
      when "/not_found_original_exception"
        raise ActionView::Template::Error.new('template', {}, AbstractController::ActionNotFound.new)
      else
        raise "puke!"
      end
    end
  end

  ProductionApp = ActionDispatch::ShowExceptions.new(Boomer.new(false))
  DevelopmentApp = ActionDispatch::ShowExceptions.new(Boomer.new(true))

  test "rescue with error page when show_exceptions is false" do
    @app = ProductionApp

    get "/", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 500
    assert_equal "500 error fixture\n", body

    get "/not_found", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_equal "404 error fixture\n", body

    get "/method_not_allowed", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 405
    assert_equal "", body
  end

  test "rescue with diagnostics message when show_exceptions is true" do
    @app = DevelopmentApp

    get "/", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 500
    assert_match(/puke/, body)

    get "/not_found", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/#{ActionController::UnknownAction.name}/, body)

    get "/method_not_allowed", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 405
    assert_match(/ActionController::MethodNotAllowed/, body)
  end

  test "localize rescue error page" do
    # Change locale
    old_locale, I18n.locale = I18n.locale, :da

    begin
      @app = ProductionApp

      get "/", {}, {'action_dispatch.show_exceptions' => true}
      assert_response 500
      assert_equal "500 localized error fixture\n", body

      get "/not_found", {}, {'action_dispatch.show_exceptions' => true}
      assert_response 404
      assert_equal "404 error fixture\n", body
    ensure
      I18n.locale = old_locale
    end
  end

  test "does not show filtered parameters" do
    @app = DevelopmentApp

    get "/", {"foo"=>"bar"}, {'action_dispatch.show_exceptions' => true,
      'action_dispatch.parameter_filter' => [:foo]}
    assert_response 500
    assert_match("&quot;foo&quot;=&gt;&quot;[FILTERED]&quot;", body)
  end

  test "show registered original exception for wrapped exceptions when show_exceptions is false" do
    @app = ProductionApp

    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/404 error/, body)
  end

  test "show registered original exception for wrapped exceptions when show_exceptions is true" do
    @app = DevelopmentApp

    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/AbstractController::ActionNotFound/, body)
  end

  test "show the controller name in the diagnostics template when controller name is present" do
    @app = DevelopmentApp
    get("/runtime_error", {}, {
      'action_dispatch.show_exceptions' => true,
      'action_dispatch.request.parameters' => {
        'action' => 'show',
        'id' => 'unknown',
        'controller' => 'featured_tile'
      }
    })
    assert_response 500
    assert_match(/RuntimeError\n    in FeaturedTileController/, body)
  end

  test "sets the HTTP charset parameter" do
    @app = DevelopmentApp

    get "/", {}, {'action_dispatch.show_exceptions' => true}
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
  end
end
