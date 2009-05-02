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

require 'action_controller/abstract'
require 'action_controller/new_base'
require 'pp' # require 'pp' early to prevent hidden_methods from not picking up the pretty-print methods until too late

require 'rubygems'
require 'rack/test'

module Rails
  def self.env
    x = Object.new
    def x.test?() true end
    x
  end
end

# Temporary base class
class Rack::TestCase < ActiveSupport::TestCase
  include Rack::Test::Methods
  
  setup do
    ActionController::Base.session_options[:key] = "abc"
    ActionController::Base.session_options[:secret] = ("*" * 30)
    
    controllers = ActionController::Base.subclasses.map do |k| 
      k.underscore.sub(/_controller$/, '')
    end
    
    ActionController::Routing.use_controllers!(controllers)
    
    # Move into a bootloader
    AbstractController::Base.subclasses.each do |klass|
      klass = klass.constantize
      next unless klass < AbstractController::Layouts
      klass.class_eval do
        _write_layout_method
      end
    end    
  end
    
  def app
    @app ||= ActionController::Dispatcher.new
  end
  
  def self.get(url)
    setup do |test|
      test.get url
    end
  end
  
  def assert_body(body)
    assert_equal body, Array.wrap(last_response.body).join
  end
  
  def self.assert_body(body)
    test "body is set to '#{body}'" do
      assert_body body
    end
  end
  
  def assert_status(code)
    assert_equal code, last_response.status
  end
  
  def self.assert_status(code)
    test "status code is set to #{code}" do
      assert_status code
    end
  end
  
  def assert_content_type(type)
    assert_equal type, last_response.headers["Content-Type"]
  end
  
  def self.assert_content_type(type)
    test "content type is set to #{type}" do
      assert_content_type(type)
    end
  end
  
  def assert_header(name, value)
    assert_equal value, last_response.headers[name]
  end
  
  def self.assert_header(name, value)
    test "'#{name}' header is set to #{value.inspect}" do
      assert_header(name, value)
    end
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