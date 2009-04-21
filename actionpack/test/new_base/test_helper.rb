$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'action_view/base'
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

module ActionController
  class Base2 < AbstractBase
    use AbstractController::Callbacks
    use AbstractController::Helpers
    use AbstractController::Logger

    use ActionController::HideActions
    use ActionController::UrlFor
    use ActionController::Renderer
    use ActionController::Layouts
    
    def self.inherited(klass)
      ::ActionController::Base2.subclasses << klass.to_s
      super
    end
    
    def self.subclasses
      @subclasses ||= []
    end
    
    def self.app_loaded!
      @subclasses.each do |subclass|
        subclass.constantize._write_layout_method
      end
    end
    
    # append_view_path File.join(File.dirname(__FILE__), '..', 'fixtures')
        
    CORE_METHODS = self.public_instance_methods
  end
end

# Temporary base class
class Rack::TestCase < ActiveSupport::TestCase
  include Rack::Test::Methods
  
  setup do
    ActionController::Base.session_options[:key] = "abc"
    ActionController::Base.session_options[:secret] = ("*" * 30)
    
    controllers = ActionController::Base2.subclasses.map do |k| 
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
    assert_equal [body], last_response.body
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

class ::ApplicationController < ActionController::Base2
end

class SimpleRouteCase < Rack::TestCase
  setup do
    ActionController::Routing::Routes.draw do |map|
      map.connect ':controller/:action/:id'
    end
  end
end