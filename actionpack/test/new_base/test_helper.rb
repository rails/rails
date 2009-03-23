$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'action_view/base'

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
    include AbstractController::Callbacks
    include AbstractController::Renderer
    include AbstractController::Helpers
    include AbstractController::Layouts
    include AbstractController::Logger
    
    include ActionController::HideActions
    include ActionController::UrlFor
    include ActionController::Layouts
    include ActionController::Renderer
    
    def self.inherited(klass)
      @subclasses ||= []
      @subclasses << klass.to_s
    end
    
    def self.subclasses
      @subclasses
    end
    
    # append_view_path File.join(File.dirname(__FILE__), '..', 'fixtures')
        
    CORE_METHODS = self.public_instance_methods
  end
end

module ActionView #:nodoc:
  class FixtureTemplate < Template
    class FixturePath < Template::Path
      def initialize(hash = {})
        @hash = {}
        
        hash.each do |k, v|
          @hash[k.sub(/\.\w+$/, '')] = FixtureTemplate.new(v, k.split("/").last, self)
        end
        
        super("fixtures://root")
      end
      
      def find_template(path)
        @hash[path]
      end
    end
    
    def initialize(body, *args)
      @body = body
      super(*args)
    end
    
    def source
      @body
    end
  
  private
  
    def find_full_path(path, load_paths)
      return '/', path
    end
  
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
  end
  
  def self.describe(text)
    class_eval <<-RUBY_EVAL
      def self.name
        "#{text}"
      end
    RUBY_EVAL
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

class SimpleRouteCase < Rack::TestCase
  setup do
    ActionController::Routing::Routes.draw do |map|
      map.connect ':controller/:action/:id'
    end
  end
end