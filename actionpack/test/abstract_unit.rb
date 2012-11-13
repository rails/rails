require File.expand_path('../../../load_paths', __FILE__)

$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

ENV['TMPDIR'] = File.join(File.dirname(__FILE__), 'tmp')

require 'active_support/core_ext/kernel/reporting'

# These are the normal settings that will be set up by Railties
# TODO: Have these tests support other combinations of these values
silence_warnings do
  Encoding.default_internal = "UTF-8"
  Encoding.default_external = "UTF-8"
end

require 'minitest/autorun'
require 'abstract_controller'
require 'action_controller'
require 'action_view'
require 'action_view/testing/resolvers'
require 'action_dispatch'
require 'active_support/dependencies'
require 'active_model'
require 'active_record'
require 'action_controller/caching'
require 'action_controller/caching/sweeping'

require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

module Rails
  class << self
    def env
      @_env ||= ActiveSupport::StringInquirer.new(ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "test")
    end
  end
end

ActiveSupport::Dependencies.hook!

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

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

module RenderERBUtils
  def view
    @view ||= begin
      path = ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH)
      view_paths = ActionView::PathSet.new([path])
      ActionView::Base.new(view_paths)
    end
  end

  def render_erb(string)
    @virtual_path = nil

    template = ActionView::Template.new(
      string.strip,
      "test template",
      ActionView::Template::Handlers::ERB,
      {})

    template.render(self, {}).strip
  end
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
    include ActionController::Testing
    # This stub emulates the Railtie including the URL helpers from a Rails application
    include SharedTestRoutes.url_helpers
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

module ActionView
  class TestCase
    # Must repeat the setup because AV::TestCase is a duplication
    # of AC::TestCase
    include ActionDispatch::SharedRoutes
  end
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
    def get(uri_or_host, path = nil, port = nil)
      host = uri_or_host.host unless path
      path ||= uri_or_host.path

      params = {'PATH_INFO'      => path,
                'REQUEST_METHOD' => 'GET',
                'HTTP_HOST'      => host}

      routes.call(params)[2].join
    end
  end
end

module RoutingTestHelpers
  def url_for(set, options, recall = nil)
    set.send(:url_for, options.merge(:only_path => true, :_recall => recall))
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
class AuthorsController < ResourcesController; end
class LogosController < ResourcesController; end

class AccountsController <  ResourcesController; end
class AdminController   <  ResourcesController; end
class ProductsController < ResourcesController; end
class ImagesController < ResourcesController; end
class PreferencesController < ResourcesController; end

module Backoffice
  class ProductsController < ResourcesController; end
  class TagsController < ResourcesController; end
  class ManufacturersController < ResourcesController; end
  class ImagesController < ResourcesController; end

  module Admin
    class ProductsController < ResourcesController; end
    class ImagesController < ResourcesController; end
  end
end
