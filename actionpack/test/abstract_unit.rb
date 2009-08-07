$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/../../activemodel/lib')
$:.unshift(File.dirname(__FILE__) + '/lib')

$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

ENV['new_base'] = "true"
$stderr.puts "Running old tests on new_base"

require 'test/unit'
require 'active_support'

require 'active_support/test_case'
require 'action_controller'
require 'fixture_template'
require 'action_controller/testing/process'
require 'action_view/test_case'
require 'action_controller/testing/integration'
require 'active_support/dependencies'
require 'active_model'

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

module ActionController
  Base.session = {
    :key         => '_testing_session',
    :secret      => '8273f16463985e2b3747dc25e30f2528'
  }
  Base.session_store = nil

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
