$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../lib')

$:.unshift(File.dirname(__FILE__) + '/../fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/../fixtures/alternate_helpers')

ENV['new_base'] = "true"
$stderr.puts "Running old tests on new_base"

require 'test/unit'
require 'active_support'

require 'active_support/test_case'
require 'action_controller/abstract'
require 'action_controller/new_base'
require 'fixture_template'
require 'action_controller/testing/process2'
require 'action_view/test_case'
require 'action_controller/testing/integration'
require 'active_support/dependencies'

$tags[:new_base] = true

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

ActiveSupport::Dependencies.hook!

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Register danish language for testing
I18n.backend.store_translations 'da', {}
I18n.backend.store_translations 'pt-BR', {}
ORIGINAL_LOCALES = I18n.available_locales.map {|locale| locale.to_s }.sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), '../fixtures')

module ActionView
  class TestCase
    setup do
      ActionController::Routing::Routes.draw do |map|
        map.connect ':controller/:action/:id'
      end
    end
  end
end

module ActionController
  Base.session = {
  :key         => '_testing_session',
  :secret      => '8273f16463985e2b3747dc25e30f2528'
}

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
    include ActionController::Testing
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

      hax = @controller._action_view.instance_variable_get(:@_rendered)

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
