# frozen_string_literal: true

require "abstract_unit"

class ShowExceptionsTest < ActionDispatch::IntegrationTest
  class Boomer
    def call(env)
      req = ActionDispatch::Request.new(env)
      case req.path
      when "/not_found"
        raise AbstractController::ActionNotFound
      when "/invalid_mimetype"
        raise ActionDispatch::Http::MimeNegotiation::InvalidType
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

  def setup
    @app = build_app
  end

  test "skip exceptions app if not showing exceptions" do
    assert_raise RuntimeError do
      get "/", env: { "action_dispatch.show_exceptions" => :none }
    end
  end

  test "rescue with error page" do
    get "/", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_equal "500 error fixture\n", body

    get "/bad_params", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_equal "400 error fixture\n", body

    get "/not_found", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_equal "404 error fixture\n", body

    get "/method_not_allowed", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_equal "", body

    get "/unknown_http_method", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_equal "", body

    get "/invalid_mimetype", headers: { "Accept" => "text/html,*", "action_dispatch.show_exceptions" => :all }
    assert_response 406
    assert_equal "", body
  end

  test "localize rescue error page" do
    old_locale, I18n.locale = I18n.locale, :da

    begin
      get "/", env: { "action_dispatch.show_exceptions" => :all }
      assert_response 500
      assert_equal "500 localized error fixture\n", body

      get "/not_found", env: { "action_dispatch.show_exceptions" => :all }
      assert_response 404
      assert_equal "404 error fixture\n", body
    ensure
      I18n.locale = old_locale
    end
  end

  test "sets the HTTP charset parameter" do
    get "/", env: { "action_dispatch.show_exceptions" => :all }
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
  end

  test "show registered original exception for wrapped exceptions" do
    get "/not_found_original_exception", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_match(/404 error/, body)
  end

  test "calls custom exceptions app" do
    exceptions_app = lambda do |env|
      assert_kind_of AbstractController::ActionNotFound, env["action_dispatch.exception"]
      assert_equal "/404", env["PATH_INFO"]
      assert_equal "/not_found_original_exception", env["action_dispatch.original_path"]
      [404, { "content-type" => "text/plain" }, ["YOU FAILED"]]
    end

    @app = build_app(exceptions_app)

    get "/not_found_original_exception", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_equal "YOU FAILED", body
  end

  test "returns an empty response if custom exceptions app returns x-cascade pass" do
    exceptions_app = lambda do |env|
      [404, { ActionDispatch::Constants::X_CASCADE => "pass" }, []]
    end

    @app = build_app(exceptions_app)

    get "/method_not_allowed", env: { "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_equal "", body
  end

  test "bad params exception is returned in the correct format" do
    get "/bad_params", env: { "action_dispatch.show_exceptions" => :all }
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
    assert_response 400
    assert_match(/400 error/, body)

    get "/bad_params.json", env: { "action_dispatch.show_exceptions" => :all }
    assert_equal "application/json; charset=utf-8", response.headers["content-type"]
    assert_response 400
    assert_equal("{\"status\":400,\"error\":\"Bad Request\"}", body)
  end

  test "failsafe prevents raising if exceptions_app raises" do
    old_stderr, $stderr = $stderr, StringIO.new
    @app = build_app(->(_) { raise })

    get "/"

    assert_response 500
    assert_match(/500 Internal Server Error/, body)
  ensure
    $stderr = old_stderr
  end

  private
    def build_app(exceptions_app = nil)
      exceptions_app ||= ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
      Rack::Lint.new(ActionDispatch::ShowExceptions.new(Rack::Lint.new(Boomer.new), exceptions_app))
    end
end
