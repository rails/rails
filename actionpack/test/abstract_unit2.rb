$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/lib')


require 'test/unit'
require 'active_support'
require 'active_support/core/all'
require 'active_support/test_case'
require 'action_controller/abstract'
require 'action_controller/new_base'
require 'fixture_template'
require 'action_controller/testing/process2'
require 'action_view/test_case'

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')

module ActionController
  
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
  
  class Base
    use ActionController::Testing
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