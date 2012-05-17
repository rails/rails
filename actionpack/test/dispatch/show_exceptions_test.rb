require 'abstract_unit'

class ShowExceptionsTest < ActionDispatch::IntegrationTest

  class Boomer
    def call(env)
      req = ActionDispatch::Request.new(env)
      case req.path
      when "/not_found"
        raise AbstractController::ActionNotFound
      when "/method_not_allowed"
        raise ActionController::MethodNotAllowed
      when "/not_found_original_exception"
        raise ActionView::Template::Error.new('template', AbstractController::ActionNotFound.new)
      else
        raise "puke!"
      end
    end
  end

  ProductionApp = ActionDispatch::ShowExceptions.new(Boomer.new, ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public"))

  test "skip exceptions app if not showing exceptions" do
    @app = ProductionApp
    assert_raise RuntimeError do
      get "/", {}, {'action_dispatch.show_exceptions' => false}
    end
  end

  test "rescue with error page" do
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

  test "localize rescue error page" do
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

  test "sets the HTTP charset parameter" do
    @app = ProductionApp

    get "/", {}, {'action_dispatch.show_exceptions' => true}
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
  end

  test "show registered original exception for wrapped exceptions" do
    @app = ProductionApp

    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_match(/404 error/, body)
  end

  test "calls custom exceptions app" do
    exceptions_app = lambda do |env|
      assert_kind_of AbstractController::ActionNotFound, env["action_dispatch.exception"]
      assert_equal "/404", env["PATH_INFO"]
      [404, { "Content-Type" => "text/plain" }, ["YOU FAILED BRO"]]
    end

    @app = ActionDispatch::ShowExceptions.new(Boomer.new, exceptions_app)
    get "/not_found_original_exception", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 404
    assert_equal "YOU FAILED BRO", body
  end

  test "returns an empty response if custom exceptions app returns X-Cascade pass" do
    exceptions_app = lambda do |env|
      [404, { "X-Cascade" => "pass" }, []]
    end

    @app = ActionDispatch::ShowExceptions.new(Boomer.new, exceptions_app)
    get "/method_not_allowed", {}, {'action_dispatch.show_exceptions' => true}
    assert_response 405
    assert_equal "", body
  end
end
