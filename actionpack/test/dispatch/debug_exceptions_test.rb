# frozen_string_literal: true

require "abstract_unit"

class DebugExceptionsTest < ActionDispatch::IntegrationTest
  InterceptedErrorInstance = StandardError.new

  class Boomer
    attr_accessor :closed

    def initialize(detailed  = false)
      @detailed = detailed
      @closed = false
    end

    # We're obliged to implement this (even though it doesn't actually
    # get called here) to properly comply with the Rack SPEC
    def each
    end

    def close
      @closed = true
    end

    def method_that_raises
      raise StandardError.new "error in framework"
    end

    def raise_nested_exceptions
      begin
        raise "First error"
      rescue
        begin
          raise "Second error"
        rescue
          raise "Third error"
        end
      end
    end

    def call(env)
      env["action_dispatch.show_detailed_exceptions"] = @detailed
      req = ActionDispatch::Request.new(env)
      case req.path
      when %r{/pass}
        [404, { "X-Cascade" => "pass" }, self]
      when %r{/not_found}
        raise AbstractController::ActionNotFound
      when %r{/runtime_error}
        raise RuntimeError
      when %r{/method_not_allowed}
        raise ActionController::MethodNotAllowed
      when %r{/intercepted_error}
        raise InterceptedErrorInstance
      when %r{/unknown_http_method}
        raise ActionController::UnknownHttpMethod
      when %r{/not_implemented}
        raise ActionController::NotImplemented
      when %r{/unprocessable_entity}
        raise ActionController::InvalidAuthenticityToken
      when %r{/not_found_original_exception}
        begin
          raise AbstractController::ActionNotFound.new
        rescue
          raise ActionView::Template::Error.new("template")
        end
      when %r{/missing_template}
        raise ActionView::MissingTemplate.new(%w(foo), "foo/index", %w(foo), false, "mailer")
      when %r{/bad_request}
        raise ActionController::BadRequest
      when %r{/missing_keys}
        raise ActionController::UrlGenerationError, "No route matches"
      when %r{/parameter_missing}
        raise ActionController::ParameterMissing, :missing_param_key
      when %r{/original_syntax_error}
        eval "broke_syntax =" # `eval` need for raise native SyntaxError at runtime
      when %r{/syntax_error_into_view}
        begin
          eval "broke_syntax ="
        rescue Exception
          template = ActionView::Template.new(File.read(__FILE__),
                                              __FILE__,
                                              ActionView::Template::Handlers::Raw.new,
                                              {})
          raise ActionView::Template::Error.new(template)
        end
      when %r{/framework_raises}
        method_that_raises
      when %r{/nested_exceptions}
        raise_nested_exceptions
      else
        raise "puke!"
      end
    end
  end

  Interceptor = proc { |request, exception| request.set_header("int", exception) }
  BadInterceptor = proc { |request, exception| raise "bad" }
  RoutesApp = Struct.new(:routes).new(SharedTestRoutes)
  ProductionApp  = ActionDispatch::DebugExceptions.new(Boomer.new(false), RoutesApp)
  DevelopmentApp = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp)
  InterceptedApp = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :default, [Interceptor])
  BadInterceptedApp = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :default, [BadInterceptor])

  test "skip diagnosis if not showing detailed exceptions" do
    @app = ProductionApp
    assert_raise RuntimeError do
      get "/", headers: { "action_dispatch.show_exceptions" => true }
    end
  end

  test "skip diagnosis if not showing exceptions" do
    @app = DevelopmentApp
    assert_raise RuntimeError do
      get "/", headers: { "action_dispatch.show_exceptions" => false }
    end
  end

  test "raise an exception on cascade pass" do
    @app = ProductionApp
    assert_raise ActionController::RoutingError do
      get "/pass", headers: { "action_dispatch.show_exceptions" => true }
    end
  end

  test "closes the response body on cascade pass" do
    boomer = Boomer.new(false)
    @app = ActionDispatch::DebugExceptions.new(boomer)
    assert_raise ActionController::RoutingError do
      get "/pass", headers: { "action_dispatch.show_exceptions" => true }
    end
    assert boomer.closed, "Expected to close the response body"
  end

  test "displays routes in a table when a RoutingError occurs" do
    @app = DevelopmentApp
    get "/pass", headers: { "action_dispatch.show_exceptions" => true }
    routing_table = body[/route_table.*<.table>/m]
    assert_match "/:controller(/:action)(.:format)", routing_table
    assert_match ":controller#:action", routing_table
    assert_no_match "&lt;|&gt;", routing_table, "there should not be escaped html in the output"
  end

  test "displays request and response info when a RoutingError occurs" do
    @app = DevelopmentApp

    get "/pass", headers: { "action_dispatch.show_exceptions" => true }

    assert_select "h2", /Request/
    assert_select "h2", /Response/
  end

  test "rescue with diagnostics message" do
    @app = DevelopmentApp

    get "/", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 500
    assert_match(/puke/, body)

    get "/not_found", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 404
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 405
    assert_match(/ActionController::MethodNotAllowed/, body)

    get "/unknown_http_method", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 405
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 400
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 400
    assert_match(/ActionController::ParameterMissing/, body)
  end

  test "rescue with text error for xhr request" do
    @app = DevelopmentApp
    xhr_request_env = { "action_dispatch.show_exceptions" => true, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

    get "/", headers: xhr_request_env
    assert_response 500
    assert_no_match(/<header>/, body)
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/RuntimeError\npuke/, body)

    Rails.stub :root, Pathname.new(".") do
      get "/", headers: xhr_request_env

      assert_response 500
      assert_match "Extracted source (around line #", body
      assert_select "pre", { count: 0 }, body
    end

    get "/not_found", headers: xhr_request_env
    assert_response 404
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: xhr_request_env
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/ActionController::MethodNotAllowed/, body)

    get "/unknown_http_method", headers: xhr_request_env
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: xhr_request_env
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: xhr_request_env
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.content_type
    assert_match(/ActionController::ParameterMissing/, body)
  end

  test "rescue with JSON error for JSON API request" do
    @app = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :api)

    get "/", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 500
    assert_no_match(/<header>/, body)
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/RuntimeError: puke/, body)

    get "/not_found", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 404
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/ActionController::MethodNotAllowed/, body)

    get "/unknown_http_method", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: { "action_dispatch.show_exceptions" => true }, as: :json
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.content_type
    assert_match(/ActionController::ParameterMissing/, body)
  end

  test "rescue with HTML format for HTML API request" do
    @app = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :api)

    get "/index.html", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 500
    assert_match(/<header>/, body)
    assert_match(/<body>/, body)
    assert_equal "text/html", response.content_type
    assert_match(/puke/, body)
  end

  test "rescue with XML format for XML API requests" do
    @app = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :api)

    get "/index.xml", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 500
    assert_equal "application/xml", response.content_type
    assert_match(/RuntimeError: puke/, body)
  end

  test "rescue with JSON format as fallback if API request format is not supported" do
    begin
      Mime::Type.register "text/wibble", :wibble

      ActionDispatch::IntegrationTest.register_encoder(:wibble,
        param_encoder: -> params { params })

      @app = ActionDispatch::DebugExceptions.new(Boomer.new(true), RoutesApp, :api)

      get "/index", headers: { "action_dispatch.show_exceptions" => true }, as: :wibble
      assert_response 500
      assert_equal "application/json", response.content_type
      assert_match(/RuntimeError: puke/, body)

    ensure
      Mime::Type.unregister :wibble
    end
  end

  test "does not show filtered parameters" do
    @app = DevelopmentApp

    get "/", params: { "foo" => "bar" }, headers: { "action_dispatch.show_exceptions" => true,
      "action_dispatch.parameter_filter" => [:foo] }
    assert_response 500
    assert_match("&quot;foo&quot;=&gt;&quot;[FILTERED]&quot;", body)
  end

  test "show registered original exception for wrapped exceptions" do
    @app = DevelopmentApp

    get "/not_found_original_exception", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 404
    assert_match(/AbstractController::ActionNotFound/, body)
  end

  test "named urls missing keys raise 500 level error" do
    @app = DevelopmentApp

    get "/missing_keys", headers: { "action_dispatch.show_exceptions" => true }
    assert_response 500

    assert_match(/ActionController::UrlGenerationError/, body)
  end

  test "show the controller name in the diagnostics template when controller name is present" do
    @app = DevelopmentApp
    get("/runtime_error", headers: {
      "action_dispatch.show_exceptions" => true,
      "action_dispatch.request.parameters" => {
        "action" => "show",
        "id" => "unknown",
        "controller" => "featured_tile"
      }
    })
    assert_response 500
    assert_match(/RuntimeError\n\s+in FeaturedTileController/, body)
  end

  test "show formatted params" do
    @app = DevelopmentApp

    params = {
      "id" => "unknown",
      "someparam" => {
        "foo" => "bar",
        "abc" => "goo"
      }
    }

    get("/runtime_error", headers: {
      "action_dispatch.show_exceptions" => true,
      "action_dispatch.request.parameters" => {
        "action" => "show",
        "controller" => "featured_tile"
      }.merge(params)
    })
    assert_response 500

    assert_includes(body, CGI.escapeHTML(PP.pp(params, "".dup, 200)))
  end

  test "sets the HTTP charset parameter" do
    @app = DevelopmentApp

    get "/", headers: { "action_dispatch.show_exceptions" => true }
    assert_equal "text/html; charset=utf-8", response.headers["Content-Type"]
  end

  test "uses logger from env" do
    @app = DevelopmentApp
    output = StringIO.new
    get "/", headers: { "action_dispatch.show_exceptions" => true, "action_dispatch.logger" => Logger.new(output) }
    assert_match(/puke/, output.rewind && output.read)
  end

  test "logs only what is necessary" do
    @app = DevelopmentApp
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)

    _old, ActionView::Base.logger = ActionView::Base.logger, logger
    begin
      get "/", headers: { "action_dispatch.show_exceptions" => true, "action_dispatch.logger" => logger }
    ensure
      ActionView::Base.logger = _old
    end

    output = io.rewind && io.read
    lines = output.lines

    # Other than the first three...
    assert_equal(["  \n", "RuntimeError (puke!):\n", "  \n"], lines.slice!(0, 3))
    lines.each do |line|
      # .. all the remaining lines should be from the backtrace
      assert_match(/:\d+:in /, line)
    end
  end

  test "logs with non active support loggers" do
    @app = DevelopmentApp
    io = StringIO.new
    logger = Logger.new(io)

    _old, ActionView::Base.logger = ActionView::Base.logger, logger
    begin
      assert_nothing_raised do
        get "/", headers: { "action_dispatch.show_exceptions" => true, "action_dispatch.logger" => logger }
      end
    ensure
      ActionView::Base.logger = _old
    end

    assert_match(/puke/, io.rewind && io.read)
  end

  test "uses backtrace cleaner from env" do
    @app = DevelopmentApp
    backtrace_cleaner = ActiveSupport::BacktraceCleaner.new

    backtrace_cleaner.stub :clean, ["passed backtrace cleaner"] do
      get "/", headers: { "action_dispatch.show_exceptions" => true, "action_dispatch.backtrace_cleaner" => backtrace_cleaner }
      assert_match(/passed backtrace cleaner/, body)
    end
  end

  test "logs exception backtrace when all lines silenced" do
    output = StringIO.new
    backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
    backtrace_cleaner.add_silencer { true }

    env = { "action_dispatch.show_exceptions" => true,
           "action_dispatch.logger" => Logger.new(output),
           "action_dispatch.backtrace_cleaner" => backtrace_cleaner }

    get "/", headers: env
    assert_operator((output.rewind && output.read).lines.count, :>, 10)
  end

  test "display backtrace when error type is SyntaxError" do
    @app = DevelopmentApp

    get "/original_syntax_error", headers: { "action_dispatch.backtrace_cleaner" => ActiveSupport::BacktraceCleaner.new }

    assert_response 500
    assert_select "#Application-Trace-0" do
      assert_select "code", /syntax error, unexpected/
    end
  end

  test "display backtrace on template missing errors" do
    @app = DevelopmentApp

    get "/missing_template"

    assert_select "header h1", /Template is missing/

    assert_select "#container h2", /^Missing template/

    assert_select "#Application-Trace-0"
    assert_select "#Framework-Trace-0"
    assert_select "#Full-Trace-0"

    assert_select "h2", /Request/
  end

  test "display backtrace when error type is SyntaxError wrapped by ActionView::Template::Error" do
    @app = DevelopmentApp

    get "/syntax_error_into_view", headers: { "action_dispatch.backtrace_cleaner" => ActiveSupport::BacktraceCleaner.new }

    assert_response 500
    assert_select "#Application-Trace-0" do
      assert_select "code", /syntax error, unexpected/
    end
  end

  test "debug exceptions app shows user code that caused the error in source view" do
    @app = DevelopmentApp
    Rails.stub :root, Pathname.new(".") do
      cleaner = ActiveSupport::BacktraceCleaner.new.tap do |bc|
        bc.add_silencer { |line| line =~ /method_that_raises/ }
        bc.add_silencer { |line| line !~ %r{test/dispatch/debug_exceptions_test.rb} }
      end

      get "/framework_raises", headers: { "action_dispatch.backtrace_cleaner" => cleaner }

      # Assert correct error
      assert_response 500
      assert_select "h2", /error in framework/

      # assert source view line is the call to method_that_raises
      assert_select "div.source:not(.hidden)" do
        assert_select "pre .line.active", /method_that_raises/
      end

      # assert first source view (hidden) that throws the error
      assert_select "div.source:first" do
        assert_select "pre .line.active", /raise StandardError\.new/
      end

      # assert application trace refers to line that calls method_that_raises is first
      assert_select "#Application-Trace-0" do
        assert_select "code a:first", %r{test/dispatch/debug_exceptions_test\.rb:\d+:in `call}
      end

      # assert framework trace that threw the error is first
      assert_select "#Framework-Trace-0" do
        assert_select "code a:first", /method_that_raises/
      end
    end
  end

  test "invoke interceptors before rendering" do
    @app = InterceptedApp
    get "/intercepted_error", headers: { "action_dispatch.show_exceptions" => true }

    assert_equal InterceptedErrorInstance, request.get_header("int")
  end

  test "bad interceptors doesn't debug exceptions" do
    @app = BadInterceptedApp

    get "/puke", headers: { "action_dispatch.show_exceptions" => true }

    assert_response 500
    assert_match(/puke/, body)
  end

  test "debug exceptions app shows all the nested exceptions in source view" do
    @app = DevelopmentApp
    Rails.stub :root, Pathname.new(".") do
      cleaner = ActiveSupport::BacktraceCleaner.new.tap do |bc|
        bc.add_silencer { |line| line !~ %r{test/dispatch/debug_exceptions_test.rb} }
      end

      get "/nested_exceptions", headers: { "action_dispatch.backtrace_cleaner" => cleaner }

      # Assert correct error
      assert_response 500
      assert_select "h2", /Third error/

      # assert source view line shows the last error
      assert_select "div.source:not(.hidden)" do
        assert_select "pre .line.active", /raise "Third error"/
      end

      # assert application trace refers to line that raises the last exception
      assert_select "#Application-Trace-0" do
        assert_select "code a:first", %r{in `rescue in rescue in raise_nested_exceptions'}
      end

      # assert the second application trace refers to the line that raises the second exception
      assert_select "#Application-Trace-1" do
        assert_select "code a:first", %r{in `rescue in raise_nested_exceptions'}
      end

      # assert the third application trace refers to the line that raises the first exception
      assert_select "#Application-Trace-2" do
        assert_select "code a:first", %r{in `raise_nested_exceptions'}
      end
    end
  end
end
