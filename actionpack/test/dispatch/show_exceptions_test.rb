require "abstract_unit"

class ShowExceptionsTest < ActionDispatch::IntegrationTest
  class Boomer
    def call(env)
      req = ActionDispatch::Request.new(env)
      case req.path
      when "/not_found"
        raise AbstractController::ActionNotFound
      when "/bad_params", "/bad_params.json"
        begin
          raise StandardError.new
        rescue
          raise ActionDispatch::Http::Parameters::ParseError
        end
      when "/method_not_allowed"
        raise ActionController::MethodNotAllowed, "PUT"
      when "/unknown_http_method"
        raise ActionController::UnknownHttpMethod
      when "/not_found_original_exception"
        begin
          raise AbstractController::ActionNotFound.new
        rescue
          raise ActionView::Template::Error.new("template")
        end
      else
        raise "puke!"
      end
    end
  end

  ProductionApp = ActionDispatch::ShowExceptions.new(Boomer.new, ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public"))

  test "skip exceptions app if not showing exceptions" do
    @app = ProductionApp
    assert_raise RuntimeError do
      get "/", headers: { "action_dispatch.show_exceptions" => false }
    end
  end

  test "rescue with error page" do
    @app = ProductionApp

    get "/", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 500
    assert_equal "500 error fixture\n", body

    get "/bad_params", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 400
    assert_equal "400 error fixture\n", body

    get "/not_found", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 404
    assert_equal "404 error fixture\n", body

    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 405
    assert_equal "", body

    get "/unknown_http_method", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 405
    assert_equal "", body
  end

  test "localize rescue error page" do
    old_locale, I18n.locale = I18n.locale, :da

    begin
      @app = ProductionApp

      get "/", headers: { "action_dispatch.show_exceptions" => true }
      assert_response 500
      assert_equal "500 localized error fixture\n", body

      get "/not_found", headers: { "action_dispatch.show_exceptions" => true }
      assert_response 404
      assert_equal "404 error fixture\n", body
    ensure
      I18n.locale = old_locale
    end
  end

  test "sets the HTTP charset parameter" do
    @app = ProductionApp

    get "/", headers: { "action_dispatch.show_exceptions" => true }
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
  end

  test "show registered original exception for wrapped exceptions" do
    @app = ProductionApp

    get "/not_found_original_exception", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 404
    assert_match(/404 error/, body)
  end

  test "calls custom exceptions app" do
    exceptions_app = lambda do |env|
      assert_kind_of AbstractController::ActionNotFound, env["action_dispatch.exception"]
      assert_equal "/404", env["PATH_INFO"]
      assert_equal "/not_found_original_exception", env["action_dispatch.original_path"]
      [404, { "Content-Type" => "text/plain" }, ["YOU FAILED"]]
    end

    @app = ActionDispatch::ShowExceptions.new(Boomer.new, exceptions_app)
    get "/not_found_original_exception", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 404
    assert_equal "YOU FAILED", body
  end

  test "returns an empty response if custom exceptions app returns X-Cascade pass" do
    exceptions_app = lambda do |env|
      [404, { "X-Cascade" => "pass" }, []]
    end

    @app = ActionDispatch::ShowExceptions.new(Boomer.new, exceptions_app)
    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 405
    assert_equal "", body
  end

  test "bad params exception is returned in the correct format" do
    @app = ProductionApp

    get "/bad_params", headers: { "action_dispatch.show_exceptions" => true }
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
    assert_response 400
    assert_match(/400 error/, body)

    get "/bad_params.json", headers: { "action_dispatch.show_exceptions" => true }
    assert_equal "application/json; charset=utf-8", response.headers["Content-Type"]
    assert_response 400
    assert_equal("{\"status\":400,\"error\":\"Bad Request\"}", body)
  end
end
