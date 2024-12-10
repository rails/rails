# frozen_string_literal: true

require "active_support/testing/strict_warnings"

$:.unshift File.expand_path("lib", __dir__)

require "active_support/core_ext/kernel/reporting"

# These are the normal settings that will be set up by Railties
# TODO: Have these tests support other combinations of these values
silence_warnings do
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

PROCESS_COUNT = (ENV["MT_CPU"] || 4).to_i

require "active_support/testing/autorun"
require "abstract_controller"
require "abstract_controller/railties/routes_helpers"
require "action_controller"
require "action_view"
require "action_view/testing/resolvers"
require "action_dispatch"
require "active_support/dependencies"
require "active_model"
require "zeitwerk"

require_relative "support/rack_parsing_override"

ActiveSupport::Cache.format_version = 7.1

module Rails
  class << self
    def env
      @_env ||= ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "test")
    end

    def application; end

    def root; end
  end
end

module ActionPackTestSuiteUtils
  def self.require_helpers(helpers_dirs)
    Array(helpers_dirs).each do |helpers_dir|
      Dir.glob("#{helpers_dir}/**/*_helper.rb") do |helper_file|
        require helper_file
      end
    end
  end
end

ActionPackTestSuiteUtils.require_helpers("#{__dir__}/fixtures/helpers")
ActionPackTestSuiteUtils.require_helpers("#{__dir__}/fixtures/alternate_helpers")

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActionController.deprecator.debug = true
ActionDispatch.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

FIXTURE_LOAD_PATH = File.join(__dir__, "fixtures")

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

SharedTestRoutes.draw do
  ActionDispatch.deprecator.silence do
    get ":controller(/:action)"
  end
end

module ActionDispatch
  module SharedRoutes
    def before_setup
      @routes = Routing::RouteSet.new
      ActionDispatch.deprecator.silence do
        @routes.draw { get ":controller(/:action)" }
      end
      super
    end
  end
end

module ActiveSupport
  class TestCase
    if RUBY_ENGINE == "ruby" && PROCESS_COUNT > 0
      parallelize(workers: PROCESS_COUNT)
    end
  end
end

class RoutedRackApp
  class Config < Struct.new(:middleware)
  end

  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk)
    @app = @stack.build(@routes)
  end

  def call(env)
    @app.call(env)
  end

  def config
    Config.new(@stack)
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use ActionDispatch::ShowExceptions, ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
      middleware.use ActionDispatch::DebugExceptions
      middleware.use ActionDispatch::ActionableExceptions
      middleware.use ActionDispatch::Callbacks
      middleware.use ActionDispatch::Cookies
      middleware.use ActionDispatch::Flash
      middleware.use Rack::MethodOverride
      middleware.use Rack::Head
      yield(middleware) if block_given?
    end
  end

  self.app = build_app

  app.routes.draw do
    ActionDispatch.deprecator.silence do
      get ":controller(/:action)"
    end
  end

  class DeadEndRoutes < ActionDispatch::Routing::RouteSet
    # Stub Rails dispatcher so it does not get controller references and
    # simply return the controller#action as Rack::Body.
    class NullController < ::ActionController::Metal
      def self.dispatch(action, req, res)
        [200, { "Content-Type" => "text/html" }, ["#{req.params[:controller]}##{action}"]]
      end
    end

    class NullControllerRequest < ActionDispatch::Request
      def controller_class
        NullController
      end
    end

    def make_request(env)
      NullControllerRequest.new env
    end
  end

  def self.stub_controllers(config = ActionDispatch::Routing::RouteSet::DEFAULT_CONFIG)
    yield DeadEndRoutes.new(config)
  end

  def with_autoload_path(path)
    path = File.join(__dir__, "fixtures", path)
    Zeitwerk.with_loader do |loader|
      loader.push_dir(path)
      loader.setup
      yield
    ensure
      loader.unload
    end
  end
end

# Temporary base class
class Rack::TestCase < ActionDispatch::IntegrationTest
  def self.testing(klass = nil)
    if klass
      @testing = "/#{klass.name.underscore}".delete_suffix("_controller")
    else
      @testing
    end
  end

  def get(thing, *args, **options)
    if thing.is_a?(Symbol)
      super("#{self.class.testing}/#{thing}", *args, **options)
    else
      super
    end
  end

  def assert_body(body)
    assert_equal body, Array(response.body).join
  end

  def assert_status(code)
    assert_equal code, response.status
  end

  def assert_response(body, status = 200, headers = {})
    assert_body body
    assert_status status
    headers.each do |header, value|
      assert_header header, value
    end
  end

  def assert_content_type(type)
    assert_equal type, response.headers["Content-Type"]
  end

  def assert_header(name, value)
    assert_equal value, response.headers[name]
  end
end

module ActionController
  class API
    extend AbstractController::Railties::RoutesHelpers.with(SharedTestRoutes)
  end

  class Base
    # This stub emulates the Railtie including the URL helpers from a Rails application
    extend AbstractController::Railties::RoutesHelpers.with(SharedTestRoutes)
    include SharedTestRoutes.mounted_helpers

    self.view_paths = FIXTURE_LOAD_PATH

    def self.test_routes(&block)
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw(&block)
      include routes.url_helpers
      routes
    end
  end

  class TestCase
    include ActionDispatch::TestProcess
    include ActionDispatch::SharedRoutes
  end
end

class ::ApplicationController < ActionController::Base
end

module ActionDispatch
  class DebugExceptions
    private
      remove_method :stderr_logger
      # Silence logger
      def stderr_logger
        nil
      end
  end
end

module ActionDispatch
  module RoutingVerbs
    def send_request(uri_or_host, method, path)
      host = uri_or_host.host unless path
      path ||= uri_or_host.path

      params = { "PATH_INFO" => path,
                 "REQUEST_METHOD" => method,
                 "HTTP_HOST" => host }

      routes.call(params)
    end

    def request_path_params(path, options = {})
      method = options[:method] || "GET"
      resp = send_request URI("http://localhost" + path), method.to_s.upcase, nil
      status = resp.first
      if status == 404
        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end
      controller.request.path_parameters
    end

    def get(uri_or_host, path = nil)
      send_request(uri_or_host, "GET", path)[2].join
    end

    def post(uri_or_host, path = nil)
      send_request(uri_or_host, "POST", path)[2].join
    end

    def put(uri_or_host, path = nil)
      send_request(uri_or_host, "PUT", path)[2].join
    end

    def delete(uri_or_host, path = nil)
      send_request(uri_or_host, "DELETE", path)[2].join
    end

    def patch(uri_or_host, path = nil)
      send_request(uri_or_host, "PATCH", path)[2].join
    end
  end
end

module RoutingTestHelpers
  def url_for(set, options)
    route_name = options.delete :use_route
    set.url_for options.merge(only_path: true), route_name
  end

  def make_set(strict = true)
    tc = self
    TestSet.new ->(c) { tc.controller = c }, strict
  end

  class TestSet < ActionDispatch::Routing::RouteSet
    class Request < DelegateClass(ActionDispatch::Request)
      def initialize(target, helpers, block, strict)
        super(target)
        @helpers = helpers
        @block = block
        @strict = strict
      end

      def controller_class
        helpers = @helpers
        block = @block
        Class.new(@strict ? super : ActionController::Base) {
          include helpers
          define_method(:process) { |name| block.call(self) }
          def to_a; [200, {}, []]; end
        }
      end
    end

    attr_reader :strict

    def initialize(block, strict = false)
      @block = block
      @strict = strict
      super()
    end

    private
      def make_request(env)
        Request.new super, url_helpers, @block, strict
      end
  end
end

class ResourcesController < ActionController::Base
  def index() head :ok end
  alias_method :show, :index
end

class CommentsController < ResourcesController; end
class AccountsController < ResourcesController; end
class ImagesController < ResourcesController; end

require "active_support/testing/method_call_assertions"

class ActiveSupport::TestCase
  include ActiveSupport::Testing::MethodCallAssertions
end

module CookieAssertions
  def parse_set_cookie_attributes(fields, attributes = {})
    if fields.is_a?(String)
      fields = fields.split(";").map(&:strip)
    end

    fields.each do |field|
      key, value = field.split("=", 2)

      # Normalize the key to lowercase:
      key.downcase!

      if value
        value.downcase!
        attributes[key] = value
      else
        attributes[key] = true
      end
    end

    attributes
  end

  # Parse the set-cookie header and return a hash of cookie names and values.
  #
  # Example:
  #   set_cookies = headers["set-cookie"]
  #   parse_set_cookies_headers(set_cookies)
  def parse_set_cookies_headers(set_cookies)
    if set_cookies.is_a?(String)
      set_cookies = set_cookies.split("\n")
    end

    cookies = {}

    set_cookies&.each do |cookie_string|
      attributes = {}

      fields = cookie_string.split(";").map(&:strip)

      # The first one is the cookie name:
      name, value = fields.shift.split("=", 2)

      attributes[:value] = value

      cookies[name] = parse_set_cookie_attributes(fields, attributes)
    end

    cookies
  end

  def assert_set_cookie_attributes(name, attributes, header = @response.headers["Set-Cookie"])
    cookies = parse_set_cookies_headers(header)
    attributes = parse_set_cookie_attributes(attributes) if attributes.is_a?(String)

    assert cookies.key?(name), "No cookie found with the name '#{name}', found cookies: #{cookies.keys.join(', ')}"
    cookie = cookies[name]

    attributes.each do |key, value|
      assert cookie.key?(key), "No attribute '#{key}' found for cookie '#{name}'"
      assert_equal value, cookie[key]
    end
  end

  def assert_not_set_cookie_attributes(name, attributes, header = @response.headers["Set-Cookie"])
    cookies = parse_set_cookies_headers(header)
    attributes = parse_set_cookie_attributes(attributes) if attributes.is_a?(String)

    assert cookies.key?(name), "No cookie found with the name '#{name}'"
    cookie = cookies[name]

    attributes.each do |key, value|
      if value == true
        assert_nil cookie[key]
      else
        assert_not_equal value, cookie[key]
      end
    end
  end

  def assert_set_cookie_header(expected, header = @response.headers["Set-Cookie"])
    # In Rack v2, this is newline delimited. In Rack v3, this is an array.
    # Normalize the comparison so that we can assert equality in both cases.

    if header.is_a?(String)
      header = header.split("\n").sort
    end

    if expected.is_a?(String)
      expected = expected.split("\n").sort
    end

    # While not strictly speaking correct, this is probably good enough for now:
    header = parse_set_cookies_headers(header)
    expected = parse_set_cookies_headers(expected)

    expected.each do |key, value|
      assert_equal value, header[key]
    end
  end

  def assert_not_set_cookie_header(expected, header = @response.headers["Set-Cookie"])
    if header.is_a?(String)
      header = header.split("\n").sort
    end

    if expected.is_a?(String)
      expected = expected.split("\n").sort
    end

    # While not strictly speaking correct, this is probably good enough for now:
    header = parse_set_cookies_headers(header)

    expected.each do |name|
      assert_not_includes(header, name)
    end
  end
end

module HeadersAssertions
  def normalize_headers(headers)
    headers.transform_keys(&:downcase)
  end

  def assert_headers(expected, actual = @response.headers)
    actual = normalize_headers(actual)
    expected.each do |key, value|
      assert_equal value, actual[key]
    end
  end

  def assert_header(key, value, actual = @response.headers)
    actual = normalize_headers(actual)
    assert_equal value, actual[key]
  end

  def assert_not_header(key, actual = @response.headers)
    actual = normalize_headers(actual)
    assert_not_includes(actual, key)
  end

  # This works for most headers, but not all, e.g. `set-cookie`.
  def normalized_join_header(header)
    header.is_a?(Array) ? header.join(",") : header
  end

  def assert_header_value(expected, header)
    header = normalized_join_header(header)
    assert_equal header, expected
  end
end

class DrivenByRackTest < ActionDispatch::SystemTestCase
  driven_by :rack_test
end

class DrivenBySeleniumWithChrome < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome
end

class DrivenBySeleniumWithHeadlessChrome < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end

class DrivenBySeleniumWithHeadlessFirefox < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_firefox
end

require_relative "../../tools/test_common"
