$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../activemodel/lib')

$:.unshift(File.dirname(__FILE__) + '/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

bundler = File.join(File.dirname(__FILE__), '..', 'vendor', 'gems', 'environment')
require bundler if File.exist?("#{bundler}.rb")

begin
  %w( rack rack/test sqlite3 ).each { |lib| require lib }
rescue LoadError => e
  abort e.message
end

ENV['TMPDIR'] = File.join(File.dirname(__FILE__), 'tmp')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'abstract_controller'
require 'action_controller'
require 'action_view'
require 'action_view/base'
require 'action_dispatch'
require 'active_model'
require 'fixture_template'
require 'action_controller/testing/process'
require 'action_controller/testing/integration'
require 'action_view/test_case'
require 'active_support/dependencies'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

ActiveSupport::Dependencies.hook!

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Register danish language for testing
I18n.backend.store_translations 'da', {}
I18n.backend.store_translations 'pt-BR', {}
ORIGINAL_LOCALES = I18n.available_locales.map {|locale| locale.to_s }.sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')

module ActionView
  class TestCase
    setup do
      ActionController::Routing::Routes.draw do |map|
        map.connect ':controller/:action/:id'
      end
    end
  end
end

# Temporary base class
class Rack::TestCase < ActionController::IntegrationTest
  setup do
    ActionController::Base.session_options[:key] = "abc"
    ActionController::Base.session_options[:secret] = ("*" * 30)
  end

  def app
    @app ||= ActionController::Dispatcher.new
  end

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
    assert_equal body, Array.wrap(response.body).join
  end

  def assert_status(code)
    assert_equal code, response.status
  end

  def assert_response(body, status = 200, headers = {})
    assert_body   body
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

class ::ApplicationController < ActionController::Base
end

module ActionController
  Base.session = {
    :key         => '_testing_session',
    :secret      => '8273f16463985e2b3747dc25e30f2528'
  }
  Base.session_store = nil

  class << Routing
    def possible_controllers
      @@possible_controllers ||= []
    end
  end

  class Base
    include ActionController::Testing

    def self.inherited(klass)
      name = klass.name.underscore.sub(/_controller$/, '')
      ActionController::Routing.possible_controllers << name unless name.blank?
      super
    end
  end
  
  Base.view_paths = FIXTURE_LOAD_PATH
  
  class TestCase
    include TestProcess

    setup do
      ActionController::Routing::Routes.draw do |map|
        map.connect ':controller/:action/:id'
      end
    end

    def assert_template(options = {}, message = nil)
      validate_request!

      hax = @controller.view_context.instance_variable_get(:@_rendered)

      case options
      when NilClass, String
        rendered = (hax[:template] || []).map { |t| t.identifier }
        msg = build_message(message,
                "expecting <?> but rendering with <?>",
                options, rendered.join(', '))
        assert_block(msg) do
          if options.nil?
            hax[:template].blank?
          else
            rendered.any? { |t| t.match(options) }
          end
        end
      when Hash
        if expected_partial = options[:partial]
          partials = hax[:partials]
          if expected_count = options[:count]
            found = partials.detect { |p, _| p.identifier.match(expected_partial) }
            actual_count = found.nil? ? 0 : found[1]
            msg = build_message(message,
                    "expecting ? to be rendered ? time(s) but rendered ? time(s)",
                     expected_partial, expected_count, actual_count)
            assert(actual_count == expected_count.to_i, msg)
          else
            msg = build_message(message,
                    "expecting partial <?> but action rendered <?>",
                    options[:partial], partials.keys)
            assert(partials.keys.any? { |p| p.identifier.match(expected_partial) }, msg)
          end
        else
          assert hax[:partials].empty?,
            "Expected no partials to be rendered"
        end
      end
    end
  end
end

class SimpleRouteCase < Rack::TestCase
  setup do
    ActionController::Routing::Routes.draw do |map|
      map.connect ':controller/:action/:id'
    end
  end
end
