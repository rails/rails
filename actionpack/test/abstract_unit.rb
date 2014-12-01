require File.expand_path('../../../load_paths', __FILE__)

$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

require 'active_support/core_ext/kernel/reporting'

# These are the normal settings that will be set up by Railties
# TODO: Have these tests support other combinations of these values
silence_warnings do
  Encoding.default_internal = "UTF-8"
  Encoding.default_external = "UTF-8"
end

require 'drb'
require 'drb/unix'
require 'tempfile'

PROCESS_COUNT = (ENV['N'] || 4).to_i

require 'active_support/testing/autorun'
require 'abstract_controller'
require 'abstract_controller/railties/routes_helpers'
require 'action_controller'
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_dispatch'
require 'active_support/dependencies'
require 'active_model'
require 'active_record'
require 'action_controller/caching'

require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

module Rails
  class << self
    def env
      @_env ||= ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "test")
    end
  end
end

ActiveSupport::Dependencies.hook!

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Register danish language for testing
I18n.backend.store_translations 'da', {}
I18n.backend.store_translations 'pt-BR', {}
ORIGINAL_LOCALES = I18n.available_locales.map {|locale| locale.to_s }.sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')
FIXTURES = Pathname.new(FIXTURE_LOAD_PATH)

module RackTestUtils
  def body_to_string(body)
    if body.respond_to?(:each)
      str = ""
      body.each {|s| str << s }
      str
    else
      body
    end
  end
  extend self
end

SharedTestRoutes = ActionDispatch::Routing::RouteSet.new

module ActionDispatch
  module SharedRoutes
    def before_setup
      @routes = SharedTestRoutes
      super
    end
  end

  # Hold off drawing routes until all the possible controller classes
  # have been loaded.
  module DrawOnce
    class << self
      attr_accessor :drew
    end
    self.drew = false

    def before_setup
      super
      return if DrawOnce.drew

      SharedTestRoutes.draw do
        get ':controller(/:action)'
      end

      ActionDispatch::IntegrationTest.app.routes.draw do
        get ':controller(/:action)'
      end

      DrawOnce.drew = true
    end
  end
end

module ActiveSupport
  class TestCase
    include ActionDispatch::DrawOnce
    if ActiveSupport::Testing::Isolation.forking_env? && PROCESS_COUNT > 0
      parallelize_me!
    end
  end
end

class RoutedRackApp
  attr_reader :routes

  def initialize(routes, &blk)
    @routes = routes
    @stack = ActionDispatch::MiddlewareStack.new(&blk).build(@routes)
  end

  def call(env)
    @stack.call(env)
  end
end

class BasicController
  attr_accessor :request

  def config
    @config ||= ActiveSupport::InheritableOptions.new(ActionController::Base.config).tap do |config|
      # VIEW TODO: View tests should not require a controller
      public_dir = File.expand_path("../fixtures/public", __FILE__)
      config.assets_dir = public_dir
      config.javascripts_dir = "#{public_dir}/javascripts"
      config.stylesheets_dir = "#{public_dir}/stylesheets"
      config.assets          = ActiveSupport::InheritableOptions.new({ :prefix => "assets" })
      config
    end
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  include ActionDispatch::SharedRoutes

  def self.build_app(routes = nil)
    RoutedRackApp.new(routes || ActionDispatch::Routing::RouteSet.new) do |middleware|
      middleware.use "ActionDispatch::ShowExceptions", ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
      middleware.use "ActionDispatch::DebugExceptions"
      middleware.use "ActionDispatch::Callbacks"
      middleware.use "ActionDispatch::ParamsParser"
      middleware.use "ActionDispatch::Cookies"
      middleware.use "ActionDispatch::Flash"
      middleware.use "Rack::Head"
      yield(middleware) if block_given?
    end
  end

  self.app = build_app

  # Stub Rails dispatcher so it does not get controller references and
  # simply return the controller#action as Rack::Body.
  class StubDispatcher < ::ActionDispatch::Routing::RouteSet::Dispatcher
    protected
    def controller_reference(controller_param)
      controller_param
    end

    def dispatch(controller, action, env)
      [200, {'Content-Type' => 'text/html'}, ["#{controller}##{action}"]]
    end
  end

  def self.stub_controllers
    old_dispatcher = ActionDispatch::Routing::RouteSet::Dispatcher
    ActionDispatch::Routing::RouteSet.module_eval { remove_const :Dispatcher }
    ActionDispatch::Routing::RouteSet.module_eval { const_set :Dispatcher, StubDispatcher }
    yield ActionDispatch::Routing::RouteSet.new
  ensure
    ActionDispatch::Routing::RouteSet.module_eval { remove_const :Dispatcher }
    ActionDispatch::Routing::RouteSet.module_eval { const_set :Dispatcher, old_dispatcher }
  end

  def with_routing(&block)
    temporary_routes = ActionDispatch::Routing::RouteSet.new
    old_app, self.class.app = self.class.app, self.class.build_app(temporary_routes)
    old_routes = SharedTestRoutes
    silence_warnings { Object.const_set(:SharedTestRoutes, temporary_routes) }

    yield temporary_routes
  ensure
    self.class.app = old_app
    self.remove!
    silence_warnings { Object.const_set(:SharedTestRoutes, old_routes) }
  end

  def with_autoload_path(path)
    path = File.join(File.dirname(__FILE__), "fixtures", path)
    if ActiveSupport::Dependencies.autoload_paths.include?(path)
      yield
    else
      begin
        ActiveSupport::Dependencies.autoload_paths << path
        yield
      ensure
        ActiveSupport::Dependencies.autoload_paths.reject! {|p| p == path}
        ActiveSupport::Dependencies.clear
      end
    end
  end
end

# Temporary base class
class Rack::TestCase < ActionDispatch::IntegrationTest
  def self.testing(klass = nil)
    if klass
      @testing = "/#{klass.name.underscore}".sub!(/_controller$/, '')
    else
      @testing
    end
  end

  def get(thing, *args)
    if thing.is_a?(Symbol)
      super("#{self.class.testing}/#{thing}", *args)
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
  class Base
    # This stub emulates the Railtie including the URL helpers from a Rails application
    extend AbstractController::Railties::RoutesHelpers.with(SharedTestRoutes)
    include SharedTestRoutes.mounted_helpers

    self.view_paths = FIXTURE_LOAD_PATH

    def self.test_routes(&block)
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw(&block)
      include routes.url_helpers
    end
  end

  class TestCase
    include ActionDispatch::TestProcess
    include ActionDispatch::SharedRoutes
  end
end


class ::ApplicationController < ActionController::Base
end

class Workshop
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  attr_accessor :id

  def initialize(id)
    @id = id
  end

  def persisted?
    id.present?
  end

  def to_s
    id.to_s
  end
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

      params = {'PATH_INFO'      => path,
                'REQUEST_METHOD' => method,
                'HTTP_HOST'      => host}

      routes.call(params)
    end

    def request_path_params(path, options = {})
      method = options[:method] || 'GET'
      resp = send_request URI('http://localhost' + path), method.to_s.upcase, nil
      status = resp.first
      if status == 404
        raise ActionController::RoutingError, "No route matches #{path.inspect}"
      end
      controller.request.path_parameters
    end

    def get(uri_or_host, path = nil)
      send_request(uri_or_host, 'GET', path)[2].join
    end

    def post(uri_or_host, path = nil)
      send_request(uri_or_host, 'POST', path)[2].join
    end

    def put(uri_or_host, path = nil)
      send_request(uri_or_host, 'PUT', path)[2].join
    end

    def delete(uri_or_host, path = nil)
      send_request(uri_or_host, 'DELETE', path)[2].join
    end

    def patch(uri_or_host, path = nil)
      send_request(uri_or_host, 'PATCH', path)[2].join
    end
  end
end

module RoutingTestHelpers
  def url_for(set, options)
    route_name = options.delete :use_route
    set.url_for options.merge(:only_path => true), route_name
  end

  def make_set(strict = true)
    tc = self
    TestSet.new ->(c) { tc.controller = c }, strict
  end

  class TestSet < ActionDispatch::Routing::RouteSet
    attr_reader :strict

    def initialize(block, strict = false)
      @block = block
      @strict = strict
      super()
    end

    class Dispatcher < ActionDispatch::Routing::RouteSet::Dispatcher
      def initialize(defaults, set, block)
        super(defaults)
        @block = block
        @set = set
      end

      def controller(params, default_controller=true)
        super(params, @set.strict)
      end

      def controller_reference(controller_param)
        block = @block
        set = @set
        super if @set.strict
        Class.new(ActionController::Base) {
          include set.url_helpers
          define_method(:process) { |name| block.call(self) }
          def to_a; [200, {}, []]; end
        }
      end
    end

    def dispatcher defaults
      TestSet::Dispatcher.new defaults, self, @block
    end
  end
end

class ResourcesController < ActionController::Base
  def index() render :nothing => true end
  alias_method :show, :index
end

class ThreadsController  < ResourcesController; end
class MessagesController < ResourcesController; end
class CommentsController < ResourcesController; end
class ReviewsController < ResourcesController; end
class LogosController < ResourcesController; end

class AccountsController <  ResourcesController; end
class AdminController   <  ResourcesController; end
class ProductsController < ResourcesController; end
class ImagesController < ResourcesController; end
class PreferencesController < ResourcesController; end

module Backoffice
  class ProductsController < ResourcesController; end
  class ImagesController < ResourcesController; end

  module Admin
    class ProductsController < ResourcesController; end
    class ImagesController < ResourcesController; end
  end
end

# Skips the current run on Rubinius using Minitest::Assertions#skip
def rubinius_skip(message = '')
  skip message if RUBY_ENGINE == 'rbx'
end
# Skips the current run on JRuby using Minitest::Assertions#skip
def jruby_skip(message = '')
  skip message if defined?(JRUBY_VERSION)
end

require 'mocha/setup' # FIXME: stop using mocha

class ForkingExecutor
  class Server
    include DRb::DRbUndumped

    def initialize
      @queue = Queue.new
    end

    def record reporter, result
      reporter.record result
    end

    def << o
      o[2] = DRbObject.new(o[2]) if o
      @queue << o
    end
    def pop; @queue.pop; end
  end

  def initialize size
    @size  = size
    @queue = Server.new
    file   = File.join Dir.tmpdir, Dir::Tmpname.make_tmpname('rails-tests', 'fd')
    @url   = "drbunix://#{file}"
    @pool  = nil
    DRb.start_service @url, @queue
  end

  def << work; @queue << work; end

  def shutdown
    pool = @size.times.map {
      fork {
        DRb.stop_service
        queue = DRbObject.new_with_uri @url
        while job = queue.pop
          klass    = job[0]
          method   = job[1]
          reporter = job[2]
          result = Minitest.run_one_method klass, method
          if result.error?
            translate_exceptions result
          end
          queue.record reporter, result
        end
      }
    }
    @size.times { @queue << nil }
    pool.each { |pid| Process.waitpid pid }
  end

  private
  def translate_exceptions(result)
    result.failures.map! { |e|
      begin
        Marshal.dump e
        e
      rescue TypeError
        ex = Exception.new e.message
        ex.set_backtrace e.backtrace
        Minitest::UnexpectedError.new ex
      end
    }
  end
end

if ActiveSupport::Testing::Isolation.forking_env? && PROCESS_COUNT > 0
  # Use N processes (N defaults to 4)
  Minitest.parallel_executor = ForkingExecutor.new(PROCESS_COUNT)
end

# FIXME: we have tests that depend on run order, we should fix that and
# remove this method call.
require 'active_support/test_case'
ActiveSupport::TestCase.test_order = :sorted
