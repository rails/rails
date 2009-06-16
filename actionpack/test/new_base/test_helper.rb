$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_view'
require 'fixture_template'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

require 'action_controller/testing/process'
require 'action_controller/testing/integration'

module Rails
  def self.env
    x = Object.new
    def x.test?() true end
    x
  end
end

# Temporary base class
class Rack::TestCase < ActionController::IntegrationTest
  setup do
    ActionController::Base.session_options[:key] = "abc"
    ActionController::Base.session_options[:secret] = ("*" * 30)

    controllers = ActionController::Base.subclasses.map do |k| 
      k.underscore.sub(/_controller$/, '')
    end

    ActionController::Routing.use_controllers!(controllers)
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

class SimpleRouteCase < Rack::TestCase
  setup do
    ActionController::Routing::Routes.draw do |map|
      map.connect ':controller/:action/:id'
    end
  end
end