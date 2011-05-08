require 'abstract_unit'

class ShowExceptionsTest < ActionDispatch::IntegrationTest

  Boomer = lambda do |env|
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

  ProductionApp = ActionDispatch::ShowExceptions.new(Boomer, false)
  DevelopmentApp = ActionDispatch::ShowExceptions.new(Boomer, true)

  test "rescue in public from a remote ip" do
    @app = ProductionApp
    self.remote_addr = '208.77.188.166'

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

  test "rescue locally from a local request" do
    @app = ProductionApp
    ['127.0.0.1', '127.0.0.127', '::1', '0:0:0:0:0:0:0:1', '0:0:0:0:0:0:0:1%0'].each do |ip_address|
      self.remote_addr = ip_address

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
  end

  test "localize public rescue message" do
    # Change locale
    old_locale, I18n.locale = I18n.locale, :da

    begin
      @app = ProductionApp
      self.remote_addr = '208.77.188.166'

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

  test "always rescue locally in development mode" do
    @app = DevelopmentApp
    self.remote_addr = '208.77.188.166'

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

  test "does not show filtered parameters" do
    @app = DevelopmentApp

    get "/", {"foo"=>"bar"}, {'action_dispatch.show_exceptions' => true,
      'action_dispatch.parameter_filter' => [:foo]}
    assert_response 500
    assert_match("&quot;foo&quot;=&gt;&quot;[FILTERED]&quot;", body)
  end

  test "show registered original exception for wrapped exceptions when consider_all_requests_local is false" do
    @app = ProductionApp
    self.remote_addr = '208.77.188.166'

    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/404 error/, body)
  end

  test "show registered original exception for wrapped exceptions when consider_all_requests_local is true" do
    @app = DevelopmentApp

    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/AbstractController::ActionNotFound/, body)
  end

  test "show the controller name in the diagnostics template when controller name is present" do
    @app = ProductionApp
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
