$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/lib')

# HAX
module ActionController

end

# TestCase
#  include TestProcess2


require 'test/unit'
require 'active_support'
require 'active_support/core/all'
require 'active_support/test_case'
require 'action_controller/abstract'
require 'action_controller/new_base'
require 'action_controller/new_base/base'
require 'action_controller/new_base/renderer' # HAX
require 'action_controller'
require 'fixture_template'
require 'action_view/test_case'

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')

module ActionController
  autoload :TestProcess2, 'action_controller/testing/process2'
  
  class ActionControllerError < StandardError #:nodoc:
  end

  class SessionRestoreError < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class RoutingError < ActionControllerError #:nodoc:
    attr_reader :failures
    def initialize(message, failures=[])
      super(message)
      @failures = failures
    end
  end

  class MethodNotAllowed < ActionControllerError #:nodoc:
    attr_reader :allowed_methods

    def initialize(*allowed_methods)
      super("Only #{allowed_methods.to_sentence(:locale => :en)} requests are allowed.")
      @allowed_methods = allowed_methods
    end

    def allowed_methods_header
      allowed_methods.map { |method_symbol| method_symbol.to_s.upcase } * ', '
    end

    def handle_response!(response)
      response.headers['Allow'] ||= allowed_methods_header
    end
  end

  class NotImplemented < MethodNotAllowed #:nodoc:
  end

  class UnknownController < ActionControllerError #:nodoc:
  end

  class UnknownAction < ActionControllerError #:nodoc:
  end

  class MissingFile < ActionControllerError #:nodoc:
  end

  class RenderError < ActionControllerError #:nodoc:
  end

  class SessionOverflowError < ActionControllerError #:nodoc:
    DEFAULT_MESSAGE = 'Your session data is larger than the data column in which it is to be stored. You must increase the size of your data column if you intend to store large data.'

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  class UnknownHttpMethod < ActionControllerError #:nodoc:
  end
  
  class Base < Http
    abstract!
    # <HAX>
    cattr_accessor :relative_url_root
    self.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
    
    cattr_reader :protected_instance_variables
    # Controller specific instance variables which will not be accessible inside views.
    @@protected_instance_variables = %w(@assigns @performed_redirect @performed_render @variables_added @request_origin @url @parent_controller
                                        @action_name @before_filter_chain_aborted @action_cache_path @_headers @_params
                                        @_flash @_response)    
    # </HAX>
    
    use AbstractController::Callbacks
    use AbstractController::Helpers
    use AbstractController::Logger

    use ActionController::HideActions
    use ActionController::UrlFor
    use ActionController::Renderer
    use ActionController::Layouts
    use ActionController::Rails2Compatibility
    use ActionController::Testing
    
    def self.protect_from_forgery() end
    
    def self.inherited(klass)
      ::ActionController::Base.subclasses << klass.to_s
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
    
    def render(action = action_name, options = {})
      if action.is_a?(Hash)
        options, action = action, nil 
      else
        options.merge! :action => action
      end
      
      super(options)
    end
    
    def render_to_body(options = {})
      options = {:template => options} if options.is_a?(String)
      super
    end
    
    def process_action
      ret = super
      render if response_body.nil?
      ret
    end
    
    def respond_to_action?(action_name)
      super || view_paths.find_by_parts?(action_name.to_s, {:formats => formats, :locales => [I18n.locale]}, controller_path)
    end
  end
  
  Base.view_paths = FIXTURE_LOAD_PATH
  
  class TestCase
    include TestProcess2
    setup do
      ActionController::Routing::Routes.draw do |map|
        map.connect ':controller/:action/:id'
      end
    end
    
    def assert_template(options = {}, message = nil)
      validate_response!

      clean_backtrace do
        case options
         when NilClass, String
          hax = @controller._action_view.instance_variable_get(:@_rendered)
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
              actual_count = found.nil? ? 0 : found.second
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
end