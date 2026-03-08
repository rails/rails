# frozen_string_literal: true

require "abstract_unit"

class DebugExceptionsTest < ActionDispatch::IntegrationTest
  InterceptedErrorInstance = StandardError.new

  class CustomActionableError < StandardError
    include ActiveSupport::ActionableError

    action "Action 1" do
      nil
    end

    action "Action 2" do
      nil
    end
  end

  class SimpleController < ActionController::Base
    def hello
      self.response_body = "hello"
    end
  end

  class Boomer
    attr_accessor :closed

    def initialize(detailed = false)
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
      raise_nested_exceptions_third
    end

    def raise_nested_exceptions_first
      raise "First error"
    end

    def raise_nested_exceptions_second
      raise_nested_exceptions_first
    rescue
      raise "Second error"
    end

    def raise_nested_exceptions_third
      raise_nested_exceptions_second
    rescue
      raise "Third error"
    end


    def call(env)
      env["action_dispatch.show_detailed_exceptions"] = @detailed
      req = ActionDispatch::Request.new(env)
      template = ActionView::Template.new(File.binread(__FILE__), __FILE__, ActionView::Template::Handlers::Raw.new, format: :html, locals: [])

      case req.path
      when "/pass"
        [404, { ActionDispatch::Constants::X_CASCADE => "pass" }, self]
      when "/not_found"
        controller = SimpleController.new
        raise AbstractController::ActionNotFound.new(nil, controller, :ello)
      when "/runtime_error"
        raise RuntimeError
      when "/method_not_allowed"
        raise ActionController::MethodNotAllowed
      when "/intercepted_error"
        raise InterceptedErrorInstance
      when "/unknown_http_method"
        raise ActionController::UnknownHttpMethod
      when "/not_implemented"
        raise ActionController::NotImplemented
      when "/invalid_mimetype"
        raise ActionDispatch::Http::MimeNegotiation::InvalidType
      when "/not_found_original_exception"
        begin
          raise AbstractController::ActionNotFound.new
        rescue
          raise ActionView::Template::Error.new(template)
        end
      when "/cause_mapped_to_rescue_responses"
        begin
          raise ActionController::ParameterMissing, :missing_param_key
        rescue
          raise NameError.new("uninitialized constant Userr")
        end
      when "/missing_template"
        raise ActionView::MissingTemplate.new(%w(foo), "foo/index", %w(foo), false, "mailer")
      when "/bad_request"
        raise ActionController::BadRequest
      when "/missing_keys"
        raise ActionController::UrlGenerationError, "No route matches"
      when "/parameter_missing"
        raise ActionController::ParameterMissing.new(:invalid_param_key, %w(valid_param_key))
      when "/original_syntax_error"
        eval "broke_syntax =" # `eval` need for raise native SyntaxError at runtime
      when "/syntax_error_into_view"
        begin
          eval "broke_syntax ="
        rescue Exception
          raise ActionView::Template::Error.new(template)
        end
      when "/framework_raises"
        method_that_raises
      when "/nested_exceptions"
        raise_nested_exceptions
      when %r{/actionable_error}
        raise CustomActionableError
      when "/utf8_template_error"
        begin
          eval "“fancy string”"
        rescue Exception
          raise ActionView::Template::Error.new(template)
        end
      else
        raise "puke!"
      end
    end
  end

  def self.build_app(app, *args)
    Rack::Lint.new(
      ActionDispatch::DebugExceptions.new(
        Rack::Lint.new(app), *args,
      ),
    )
  end

  Interceptor = proc { |request, exception| request.set_header("int", exception) }
  BadInterceptor = proc { |request, exception| raise "bad" }
  RoutesApp = Struct.new(:routes).new(SharedTestRoutes)
  ProductionApp  = build_app(Boomer.new(false), RoutesApp)
  DevelopmentApp = build_app(Boomer.new(true), RoutesApp)
  InterceptedApp = build_app(Boomer.new(true), RoutesApp, :default, [Interceptor])
  BadInterceptedApp = build_app(Boomer.new(true), RoutesApp, :default, [BadInterceptor])
  ApiApp = build_app(Boomer.new(true), RoutesApp, :api)

  test "skip diagnosis if not showing detailed exceptions" do
    @app = ProductionApp
    assert_raise RuntimeError do
      get "/", headers: { "action_dispatch.show_exceptions" => :all }
    end
  end

  test "skip diagnosis if not showing exceptions" do
    @app = DevelopmentApp
    assert_raise RuntimeError do
      get "/", headers: { "action_dispatch.show_exceptions" => :none }
    end
  end

  test "raise an exception on cascade pass" do
    @app = ProductionApp
    assert_raise ActionController::RoutingError do
      get "/pass", headers: { "action_dispatch.show_exceptions" => :all }
    end
  end

  test "closes the response body on cascade pass" do
    boomer = Boomer.new(false)
    @app = self.class.build_app(boomer)
    assert_raise ActionController::RoutingError do
      get "/pass", headers: { "action_dispatch.show_exceptions" => :all }
    end
    assert boomer.closed, "Expected to close the response body"
  end

  test "returns empty body on HEAD cascade pass" do
    @app = DevelopmentApp

    head "/pass"

    assert_response 404
    assert_equal "", body
  end

  test "displays routes in a table when a RoutingError occurs" do
    @app = DevelopmentApp
    get "/pass", headers: { "action_dispatch.show_exceptions" => :all }
    routing_table = body[/route_table.*<.table>/m]
    assert_match "/:controller(/:action)(.:format)", routing_table
    assert_match ":controller#:action", routing_table
    assert_no_match "&lt;|&gt;", routing_table, "there should not be escaped HTML in the output"
  end

  test "displays request and response info when a RoutingError occurs" do
    @app = DevelopmentApp

    get "/pass", headers: { "action_dispatch.show_exceptions" => :all }

    assert_select "h2", /Request/
    assert_select "h2", /Response/
  end

  test "rescue with diagnostics message" do
    @app = DevelopmentApp

    get "/", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_match(/<body>/, body)
    assert_match(/puke/, body)

    get "/not_found", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_match(/<body>/, body)
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_match(/<body>/, body)
    assert_match(/ActionController::MethodNotAllowed/, body)

    process :unknown, "/unknown_http_method", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_match(/<body>/, body)
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_match(/<body>/, body)
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_match(/<body>/, body)
    assert_match(/ActionController::ParameterMissing/, body)

    get "/invalid_mimetype", headers: { "Accept" => "text/html,*", "action_dispatch.show_exceptions" => :all }
    assert_response 406
    assert_match(/<body>/, body)
    assert_match(/ActionDispatch::Http::MimeNegotiation::InvalidType/, body)
  end

  test "rescue with text error for xhr request" do
    @app = DevelopmentApp
    xhr_request_env = { "action_dispatch.show_exceptions" => :all, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

    get "/", headers: xhr_request_env
    assert_response 500
    assert_no_match(/<header>/, body)
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.media_type
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
    assert_equal "text/plain", response.media_type
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: xhr_request_env
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.media_type
    assert_match(/ActionController::MethodNotAllowed/, body)

    process :unknown, "/unknown_http_method", headers: xhr_request_env
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.media_type
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: xhr_request_env
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.media_type
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: xhr_request_env
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/plain", response.media_type
    assert_match(/ActionController::ParameterMissing/, body)
  end

  test "rescue with text error and markdown format when text/markdown is preferred" do
    @app = DevelopmentApp

    get "/", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/RuntimeError/, body)
    assert_match(/puke/, body)

    get "/not_found", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/ActionController::MethodNotAllowed/, body)

    process :unknown, "/unknown_http_method", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: { "Accept" => "text/markdown", "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "text/markdown", response.media_type
    assert_match(/ActionController::ParameterMissing/, body)
  end

  test "rescue with JSON error for JSON API request" do
    @app = ApiApp

    get "/", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 500
    assert_no_match(/<header>/, body)
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/RuntimeError: puke/, body)

    get "/not_found", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 404
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/#{AbstractController::ActionNotFound.name}/, body)

    get "/method_not_allowed", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/ActionController::MethodNotAllowed/, body)

    process :unknown, "/unknown_http_method", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 405
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/ActionController::UnknownHttpMethod/, body)

    get "/bad_request", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/ActionController::BadRequest/, body)

    get "/parameter_missing", headers: { "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 400
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/ActionController::ParameterMissing/, body)

    get "/invalid_mimetype", headers: { "Accept" => "text/html,*", "action_dispatch.show_exceptions" => :all }, as: :json
    assert_response 406
    assert_no_match(/<body>/, body)
    assert_equal "application/json", response.media_type
    assert_match(/ActionDispatch::Http::MimeNegotiation::InvalidType/, body)
  end

  test "rescue with suggestions" do
    @app = DevelopmentApp

    get "/not_found", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_select("b", /Did you mean\?/)
    assert_select("li", "hello")

    get "/parameter_missing", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 400
    assert_select("b", /Did you mean\?/)
    assert_select("li", "valid_param_key")
  end

  test "rescue with HTML format for HTML API request" do
    @app = ApiApp

    get "/index.html", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_match(/<header>/, body)
    assert_match(/<body>/, body)
    assert_equal "text/html", response.media_type
    assert_match(/puke/, body)
  end

  test "rescue with XML format for XML API requests" do
    @app = ApiApp

    get "/index.xml", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_equal "application/xml", response.media_type
    assert_match(/RuntimeError: puke/, body)
  end

  test "rescue with JSON format as fallback if API request format is not supported" do
    Mime::Type.register "text/wibble", :wibble

    ActionDispatch::IntegrationTest.register_encoder(:wibble,
      param_encoder: -> params { params })

    @app = ApiApp

    get "/index", headers: { "action_dispatch.show_exceptions" => :all }, as: :wibble
    assert_response 500
    assert_equal "application/json", response.media_type
    assert_match(/RuntimeError: puke/, body)

  ensure
    Mime::Type.unregister :wibble
  end

  test "does not show filtered parameters" do
    @app = DevelopmentApp

    get "/", params: { "foo" => "bar" }, headers: { "action_dispatch.show_exceptions" => :all,
      "action_dispatch.parameter_filter" => [:foo] }
    assert_response 500

    assert_match(ERB::Util.html_escape({ "foo" => "[FILTERED]" }.inspect[1..-2]), body)
  end

  test "show registered original exception if the last exception is TemplateError" do
    @app = DevelopmentApp

    get "/not_found_original_exception", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 404
    assert_match %r{AbstractController::ActionNotFound}, body
    assert_match %r{Showing <i>.*test/dispatch/debug_exceptions_test.rb</i>}, body
  end

  test "show the last exception and cause even when the cause is mapped to rescue_responses" do
    @app = DevelopmentApp

    get "/cause_mapped_to_rescue_responses", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500
    assert_match %r{ActionController::ParameterMissing}, body
    assert_match %r{NameError}, body
  end

  test "named URLs missing keys raise 500 level error" do
    @app = DevelopmentApp

    get "/missing_keys", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500

    assert_match(/ActionController::UrlGenerationError/, body)
  end

  test "show the controller name in the diagnostics template when controller name is present" do
    @app = DevelopmentApp
    get("/runtime_error", headers: {
      "action_dispatch.show_exceptions" => :all,
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
      "action_dispatch.show_exceptions" => :all,
      "action_dispatch.request.parameters" => {
        "action" => "show",
        "controller" => "featured_tile"
      }.merge(params)
    })
    assert_response 500

    assert_includes(body, ERB::Util.html_escape(PP.pp(params, +"", 200)))
  end

  test "sets the HTTP charset parameter" do
    @app = DevelopmentApp

    get "/", headers: { "action_dispatch.show_exceptions" => :all }
    assert_equal "text/html; charset=utf-8", response.headers["content-type"]
  end

  test "uses logger from env" do
    @app = DevelopmentApp
    output = StringIO.new
    get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.logger" => Logger.new(output) }
    assert_match(/puke/, output.rewind && output.read)
  end

  test "logs at configured log level" do
    @app = DevelopmentApp
    output = StringIO.new
    logger = Logger.new(output)
    logger.level = Logger::WARN

    get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.logger" => logger, "action_dispatch.debug_exception_log_level" => Logger::INFO }
    assert_no_match(/puke/, output.rewind && output.read)

    get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.logger" => logger, "action_dispatch.debug_exception_log_level" => Logger::ERROR }
    assert_match(/puke/, output.rewind && output.read)
  end

  test "logs only what is necessary" do
    @app = DevelopmentApp
    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)

    _old, ActionView::Base.logger = ActionView::Base.logger, logger
    begin
      get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.logger" => logger }
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
        get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.logger" => logger }
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
      get "/", headers: { "action_dispatch.show_exceptions" => :all, "action_dispatch.backtrace_cleaner" => backtrace_cleaner }
      assert_match(/passed backtrace cleaner/, body)
    end
  end

  test "logs exception backtrace when all lines silenced" do
    @app = DevelopmentApp

    output = StringIO.new
    backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
    backtrace_cleaner.add_silencer { true }

    env = { "action_dispatch.show_exceptions"   => :all,
            "action_dispatch.logger"            => Logger.new(output),
            "action_dispatch.backtrace_cleaner" => backtrace_cleaner }

    get "/", headers: env
    assert_operator((output.rewind && output.read).lines.count, :>, 10)
  end

  test "doesn't log the framework backtrace when error type is a routing error" do
    @app = ProductionApp

    output = StringIO.new
    backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
    backtrace_cleaner.add_silencer { true }

    env = { "action_dispatch.show_exceptions"       => :all,
            "action_dispatch.logger"                => Logger.new(output),
            "action_dispatch.log_rescued_responses" => true,
            "action_dispatch.backtrace_cleaner"     => backtrace_cleaner }

    assert_raises ActionController::RoutingError do
      get "/pass", headers: env
    end

    log = output.rewind && output.read

    assert_includes log, "ActionController::RoutingError (No route matches [GET] \"/pass\")"
    assert_equal 3, log.lines.count
  end

  test "doesn't log the framework backtrace when error type is a invalid mime type" do
    @app = ProductionApp

    output = StringIO.new
    backtrace_cleaner = ActiveSupport::BacktraceCleaner.new
    backtrace_cleaner.add_silencer { true }

    env = { "Accept" => "text/html,*",
            "action_dispatch.show_exceptions"       => :all,
            "action_dispatch.logger"                => Logger.new(output),
            "action_dispatch.log_rescued_responses" => true,
            "action_dispatch.backtrace_cleaner"     => backtrace_cleaner }

    assert_raises ActionDispatch::Http::MimeNegotiation::InvalidType do
      get "/invalid_mimetype", headers: env
    end

    log = output.rewind && output.read

    assert_includes log, "ActionDispatch::Http::MimeNegotiation::InvalidType (ActionDispatch::Http::MimeNegotiation::InvalidType)"
    assert_equal 3, log.lines.count
  end

  test "skips logging when rescued and log_rescued_responses is false" do
    @app = DevelopmentApp

    output = StringIO.new

    env = { "action_dispatch.show_exceptions"       => :all,
            "action_dispatch.logger"                => Logger.new(output),
            "action_dispatch.log_rescued_responses" => false }

    get "/parameter_missing", headers: env
    assert_response 400
    assert_empty (output.rewind && output.read).lines
  end

  test "does not skip logging when rescued and log_rescued_responses is true" do
    @app = DevelopmentApp

    output = StringIO.new

    env = { "action_dispatch.show_exceptions"       => :all,
            "action_dispatch.logger"                => Logger.new(output),
            "action_dispatch.log_rescued_responses" => true }

    get "/parameter_missing", headers: env
    assert_response 400
    assert_not_empty (output.rewind && output.read).lines
  end

  test "logs exception causes" do
    @app = DevelopmentApp

    output = StringIO.new

    env = { "action_dispatch.show_exceptions"       => :all,
            "action_dispatch.logger"                => Logger.new(output),
            "action_dispatch.log_rescued_responses" => true }

    get "/nested_exceptions", headers: env
    assert_response 500
    log = output.rewind && output.read

    # Splitting into paragraphs to be easier to see difference/error when there is one
    paragraphs = log.split(/\n\s*\n/)

    assert_includes(paragraphs[0], <<~MSG.strip)
      RuntimeError (Third error)
      Caused by: RuntimeError (Second error)
      Caused by: RuntimeError (First error)
    MSG

    assert_includes(paragraphs[1], <<~MSG.strip)
      Information for: RuntimeError (Third error):
    MSG

    if RUBY_VERSION >= "3.4"
      # Changes to the format of exception backtraces
      # https://bugs.ruby-lang.org/issues/16495 (use single quote instead of backtrace)
      # https://bugs.ruby-lang.org/issues/20275 (don't have entry for rescue in)
      # And probably more, they now show the class too
      assert_match Regexp.new(<<~REGEX.strip), paragraphs[2]
        \\A.*in '.*raise_nested_exceptions_third'
        .*in '.*raise_nested_exceptions'
      REGEX

      assert_includes(paragraphs[3], <<~MSG.strip)
        Information for cause: RuntimeError (Second error):
      MSG

      assert_match Regexp.new(<<~REGEX.strip), paragraphs[4]
        \\A.*in '.*raise_nested_exceptions_second'
        .*in '.*raise_nested_exceptions_third'
        .*in '.*raise_nested_exceptions'
      REGEX


      assert_includes(paragraphs[5], <<~MSG.strip)
        Information for cause: RuntimeError (First error):
      MSG

      assert_match Regexp.new(<<~REGEX.strip), paragraphs[6]
        \\A.*in '.*raise_nested_exceptions_first'
        .*in '.*raise_nested_exceptions_second'
        .*in '.*raise_nested_exceptions_third'
        .*in '.*raise_nested_exceptions'
      REGEX
    else
      assert_match Regexp.new(<<~REGEX.strip), paragraphs[2]
        \\A.*in `rescue in raise_nested_exceptions_third'
        .*in `raise_nested_exceptions_third'
        .*in `raise_nested_exceptions'
      REGEX

      assert_includes(paragraphs[3], <<~MSG.strip)
        Information for cause: RuntimeError (Second error):
      MSG

      assert_match Regexp.new(<<~REGEX.strip), paragraphs[4]
        \\A.*in `rescue in raise_nested_exceptions_second'
        .*in `raise_nested_exceptions_second'
        .*in `raise_nested_exceptions_third'
        .*in `raise_nested_exceptions'
      REGEX


      assert_includes(paragraphs[5], <<~MSG.strip)
        Information for cause: RuntimeError (First error):
      MSG

      assert_match Regexp.new(<<~REGEX.strip), paragraphs[6]
        \\A.*in `raise_nested_exceptions_first'
        .*in `raise_nested_exceptions_second'
        .*in `raise_nested_exceptions_third'
        .*in `raise_nested_exceptions'
      REGEX
    end
  end

  test "display backtrace when error type is SyntaxError" do
    @app = DevelopmentApp

    get "/original_syntax_error", headers: { "action_dispatch.backtrace_cleaner" => ActiveSupport::BacktraceCleaner.new }

    assert_response 500
    assert_select "#Application-Trace-0" do
      assert_select "code", /syntax error, unexpected|syntax errors found/
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
      assert_select "code", /syntax error, unexpected|syntax errors found/
    end
    assert_match %r{Showing <i>.*test/dispatch/debug_exceptions_test.rb</i>}, body
  end

  test "debug exceptions app shows user code that caused the error in source view" do
    @app = DevelopmentApp
    Rails.stub :root, Pathname.new(".") do
      cleaner = ActiveSupport::BacktraceCleaner.new.tap do |bc|
        bc.add_silencer { |line| line.match?(/method_that_raises/) }
        bc.add_silencer { |line| !line.match?(%r{test/dispatch/debug_exceptions_test.rb}) }
      end

      get "/framework_raises", headers: { "action_dispatch.backtrace_cleaner" => cleaner }

      # Assert correct error
      assert_response 500
      assert_select "div.exception-message" do
        assert_select "div", /error in framework/
      end

      # assert source view line is the call to method_that_raises
      assert_select "div.source:not(.hidden)" do
        assert_select "pre .line.active", /method_that_raises/
      end

      # assert first source view (hidden) that throws the error
      assert_select "div.source" do
        assert_select "pre .line.active", /raise StandardError\.new/
      end

      # assert application trace refers to line that calls method_that_raises is first
      assert_select "#Application-Trace-0" do
        assert_select "code a:first", %r{test/dispatch/debug_exceptions_test\.rb:\d+:in .*call}
      end

      # assert framework trace that threw the error is first
      assert_select "#Framework-Trace-0" do
        assert_select "code a:first", /method_that_raises/
      end
    end
  end

  test "invoke interceptors before rendering" do
    @app = InterceptedApp
    get "/intercepted_error", headers: { "action_dispatch.show_exceptions" => :all }

    assert_equal InterceptedErrorInstance, request.get_header("int")
  end

  test "bad interceptors doesn't debug exceptions" do
    @app = BadInterceptedApp

    get "/puke", headers: { "action_dispatch.show_exceptions" => :all }

    assert_response 500
    assert_match(/puke/, body)
  end

  test "debug exceptions app shows all the nested exceptions in source view" do
    @app = DevelopmentApp
    Rails.stub :root, Pathname.new(".") do
      cleaner = ActiveSupport::BacktraceCleaner.new.tap do |bc|
        bc.add_silencer { |line| !line.match?(%r{test/dispatch/debug_exceptions_test.rb}) }
      end

      get "/nested_exceptions", headers: { "action_dispatch.backtrace_cleaner" => cleaner }

      # Assert correct error
      assert_response 500
      assert_select "div.exception-message" do
        assert_select "div", /Third error/
      end

      # assert source view line shows the last error
      assert_select "div.source:not(.hidden)" do
        assert_select "pre .line.active", /raise "Third error"/
      end

      if RUBY_VERSION >= "3.4"
        # Possible Ruby 3.4-dev bug: https://bugs.ruby-lang.org/issues/19117#note-45
        # assert application trace refers to line that raises the last exception
        assert_select "#Application-Trace-0" do
          assert_select "code a:first", %r{in '.*raise_nested_exceptions_third'}
        end

        # assert the second application trace refers to the line that raises the second exception
        assert_select "#Application-Trace-1" do
          assert_select "code a:first", %r{in '.*raise_nested_exceptions_second'}
        end
      else
        # assert application trace refers to line that raises the last exception
        assert_select "#Application-Trace-0" do
          assert_select "code a:first", %r{in [`']rescue in .*raise_nested_exceptions_third'}
        end

        # assert the second application trace refers to the line that raises the second exception
        assert_select "#Application-Trace-1" do
          assert_select "code a:first", %r{in [`']rescue in .*raise_nested_exceptions_second'}
        end
      end

      # assert the third application trace refers to the line that raises the first exception
      assert_select "#Application-Trace-2" do
        assert_select "code a:first", %r{in [`'].*raise_nested_exceptions_first'}
      end
    end
  end

  test "shows the link to edit the file in the editor" do
    @app = DevelopmentApp
    ActiveSupport::Editor.stub(:current, ActiveSupport::Editor.find("atom")) do
      get "/actionable_error"

      assert_select "code a.edit-icon"
      assert_includes body, "atom://core/open"
    end
  end

  test "editor can handle syntax errors" do
    @app = DevelopmentApp
    ActiveSupport::Editor.stub(:current, ActiveSupport::Editor.find("atom")) do
      get "/syntax_error_into_view"

      assert_response 500
      assert_select "#Application-Trace-0" do
        assert_select "code", /syntax error, unexpected|syntax errors found/
      end
    end
  end

  test "shows a buttons for every action in an actionable error" do
    @app = DevelopmentApp
    Rails.stub :root, Pathname.new(".") do
      cleaner = ActiveSupport::BacktraceCleaner.new.tap do |bc|
        bc.add_silencer { |line| !line.match?(%r{test/dispatch/debug_exceptions_test.rb}) }
      end

      get "/actionable_error", headers: { "action_dispatch.backtrace_cleaner" => cleaner }

      # Assert correct error
      assert_response 500

      assert_select 'input[value="Action 1"]'
      assert_select 'input[value="Action 2"]'
    end
  end

  test "debug exceptions app shows diagnostics when malformed query parameters are provided" do
    @app = DevelopmentApp

    get "/bad_request?x[y]=1&x[y][][w]=2"

    assert_response 400
    assert_match "ActionController::BadRequest", body
  end

  test "debug exceptions app shows diagnostics when malformed query parameters are provided by XHR" do
    @app = DevelopmentApp
    xhr_request_env = { "action_dispatch.show_exceptions" => :all, "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

    get "/bad_request?x[y]=1&x[y][][w]=2", headers: xhr_request_env

    assert_response 400
    assert_match "ActionController::BadRequest", body
  end

  test "debug exceptions app shows diagnostics for template errors that contain UTF-8 characters" do
    @app = DevelopmentApp

    io = StringIO.new
    logger = ActiveSupport::Logger.new(io)

    get "/utf8_template_error", headers: { "action_dispatch.logger" => logger }

    assert_response 500
    assert_select "#container p", /Showing #{__FILE__} where line #\d+ raised/
    assert_select "#container code", /undefined local variable or method ['`]string”'/
  end

  test "includes copy button in error pages" do
    @app = DevelopmentApp

    get "/", headers: { "action_dispatch.show_exceptions" => :all }
    assert_response 500

    assert_match %r{<button onclick="copyAsText\.bind\(this\)\(\)">Copy as text</button>}, body
    assert_match %r{<script type="text/plain" id="exception-message-for-copy">.*RuntimeError \(puke}m, body
  end

  test "copy button not shown for XHR requests" do
    @app = DevelopmentApp

    get "/", headers: {
      "action_dispatch.show_exceptions" => :all,
      "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest"
    }

    assert_response 500
    assert_no_match %r{<button}, body
    assert_no_match %r{<script}, body
  end

  test "exception message includes causes for nested exceptions" do
    @app = DevelopmentApp

    get "/nested_exceptions", headers: { "action_dispatch.show_exceptions" => :all }

    script_content = body[%r{<script type="text/plain" id="exception-message-for-copy">(.*?)</script>}m, 1]
    assert_match %r{Third error}, script_content
    assert_match %r{Caused by:.*Second error}m, script_content
  end

  test "translate_path_for_editor returns original path when RAILS_HOST_APP_PATH is not set" do
    debug_view = ActionDispatch::DebugView.new({})
    path = "/workspaces/rails/app/models/user.rb"

    stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, nil) do
      result = debug_view.send(:translate_path_for_editor, path)
      assert_equal path, result
    end
  end

  test "translate_path_for_editor returns original path when RAILS_HOST_APP_PATH is empty string" do
    debug_view = ActionDispatch::DebugView.new({})
    path = "/workspaces/rails/app/models/user.rb"

    stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "") do
      result = debug_view.send(:translate_path_for_editor, path)
      assert_equal path, result
    end
  end

  test "translate_path_for_editor translates paths within Rails.root when RAILS_HOST_APP_PATH is set" do
    debug_view = ActionDispatch::DebugView.new({})

    Rails.stub :root, Pathname.new("/workspaces/rails") do
      path = "/workspaces/rails/app/models/user.rb"

      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal "/host/myapp/app/models/user.rb", result
      end
    end
  end

  test "translate_path_for_editor handles paths with trailing separator in Rails.root" do
    debug_view = ActionDispatch::DebugView.new({})

    Rails.stub :root, Pathname.new("/workspaces/rails/") do
      path = "/workspaces/rails/app/controllers/application_controller.rb"

      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal "/host/myapp/app/controllers/application_controller.rb", result
      end
    end
  end

  test "translate_path_for_editor returns original path for files outside Rails.root" do
    debug_view = ActionDispatch::DebugView.new({})

    Rails.stub :root, Pathname.new("/workspaces/rails") do
      path = "/usr/lib/ruby/some_gem.rb"

      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal path, result
      end
    end
  end

  test "translate_path_for_editor returns original path when path is similar but not child of Rails.root" do
    debug_view = ActionDispatch::DebugView.new({})

    Rails.stub :root, Pathname.new("/workspaces/app") do
      # Path starts with Rails.root but isn't actually a child
      path = "/workspaces/app2/models/user.rb"

      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal path, result
      end
    end
  end

  test "translate_path_for_editor handles nested paths correctly" do
    debug_view = ActionDispatch::DebugView.new({})

    Rails.stub :root, Pathname.new("/workspaces/rails") do
      path = "/workspaces/rails/app/views/layouts/application.html.erb"

      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/Users/developer/projects/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal "/Users/developer/projects/myapp/app/views/layouts/application.html.erb", result
      end
    end
  end

  test "translate_path_for_editor returns original path when Rails is not defined" do
    debug_view = ActionDispatch::DebugView.new({})
    path = "/workspaces/rails/app/models/user.rb"

    # Temporarily hide Rails constant
    rails_backup = Rails
    Object.send(:remove_const, :Rails)

    stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
      result = debug_view.send(:translate_path_for_editor, path)
      assert_equal path, result
    end
  ensure
    ::Rails = rails_backup
  end

  test "translate_path_for_editor returns original path when Rails.root is nil" do
    debug_view = ActionDispatch::DebugView.new({})
    path = "/workspaces/rails/app/models/user.rb"

    Rails.stub :root, nil do
      stub_const(ActionDispatch::DebugView, :HOST_APP_PATH, "/host/myapp") do
        result = debug_view.send(:translate_path_for_editor, path)
        assert_equal path, result
      end
    end
  end
end
