# frozen_string_literal: true

require "active_support/testing/strict_warnings"

$:.unshift File.expand_path("lib", __dir__)

ENV["TMPDIR"] = File.expand_path("tmp", __dir__)

require "active_support/core_ext/kernel/reporting"

# These are the normal settings that will be set up by Railties
# TODO: Have these tests support other combinations of these values
silence_warnings do
  Encoding.default_internal = Encoding::UTF_8
  Encoding.default_external = Encoding::UTF_8
end

require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "action_controller"
require "action_view"
require "action_view/testing/resolvers"
require "active_support/dependencies"
require "active_model"

module ActionViewTestSuiteUtils
  def self.require_helpers(helpers_dirs)
    Array(helpers_dirs).each do |helpers_dir|
      Dir.glob("#{helpers_dir}/**/*_helper.rb") do |helper_file|
        require helper_file
      end
    end
  end
end

ActionViewTestSuiteUtils.require_helpers("#{__dir__}/fixtures/helpers")
ActionViewTestSuiteUtils.require_helpers("#{__dir__}/fixtures/alternate_helpers")

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActionView.deprecator.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

ORIGINAL_LOCALES = I18n.available_locales.map(&:to_s).sort

FIXTURE_LOAD_PATH = File.expand_path("fixtures", __dir__)

module RenderERBUtils
  def view
    @view ||= begin
      path = ActionView::FileSystemResolver.new(FIXTURE_LOAD_PATH)
      view_paths = ActionView::PathSet.new([path])
      view = ActionView::Base.with_empty_template_cache
      view.with_view_paths(view_paths)
    end
  end

  def render_erb(string)
    @virtual_path = nil

    template = ActionView::Template.new(
      string.strip,
      "test template",
      ActionView::Template.handler_for_extension(:erb),
      format: :html, locals: [])

    view = ActionView::Base.with_empty_template_cache
    template.render(view.empty, {}).strip
  end
end

class BasicController
  attr_accessor :request, :response

  def config
    @config ||= ActiveSupport::InheritableOptions.new(ActionController::Base.config).tap do |config|
      # VIEW TODO: View tests should not require a controller
      public_dir = File.expand_path("fixtures/public", __dir__)
      config.assets_dir = public_dir
      config.javascripts_dir = "#{public_dir}/javascripts"
      config.stylesheets_dir = "#{public_dir}/stylesheets"
      config.assets          = ActiveSupport::InheritableOptions.new(prefix: "assets")
      config
    end
  end
end

class ActionDispatch::IntegrationTest < ActiveSupport::TestCase
  self.app = ActionDispatch::MiddlewareStack.new do |middleware|
    middleware.use ActionDispatch::ShowExceptions, ActionDispatch::PublicExceptions.new("#{FIXTURE_LOAD_PATH}/public")
    middleware.use ActionDispatch::DebugExceptions
    middleware.use ActionDispatch::Callbacks
    middleware.use ActionDispatch::Cookies
    middleware.use ActionDispatch::Flash
    middleware.use Rack::Head
  end
end

ActionView::RoutingUrlFor.include(ActionDispatch::Routing::UrlFor)

module ActionController
  class Base
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

    def self.with_routes(&block)
      setup do
        @routes = ActionDispatch::Routing::RouteSet.new
        @routes.draw(&block)

        @controller.singleton_class.include @routes.url_helpers if @controller
      end
    end
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

class ActiveSupport::TestCase
  if Process.respond_to?(:fork) && !Gem.win_platform?
    parallelize
  else
    parallelize(with: :threads)
  end

  include ActiveSupport::Testing::MethodCallAssertions
end

require_relative "../../tools/test_common"
