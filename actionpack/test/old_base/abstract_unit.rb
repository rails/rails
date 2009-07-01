if ENV['new_base']
  puts *caller
  raise 'new_base/abstract_unit already loaded'
end
$:.unshift(File.dirname(__FILE__) + '/../lib')
$:.unshift(File.dirname(__FILE__) + '/../../activesupport/lib')
$:.unshift(File.dirname(__FILE__) + '/fixtures/helpers')
$:.unshift(File.dirname(__FILE__) + '/fixtures/alternate_helpers')

require 'rubygems'
require 'yaml'
require 'stringio'
require 'test/unit'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller'
require 'action_controller/testing/process'
require 'action_view/test_case'

$tags[:old_base] = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

ActionController::Base.logger = nil
ActionController::Routing::Routes.reload rescue nil

ActionController::Base.session_store = nil

# Register danish language for testing
I18n.backend.store_translations 'da', {}
I18n.backend.store_translations 'pt-BR', {}
ORIGINAL_LOCALES = I18n.available_locales.map {|locale| locale.to_s }.sort

FIXTURE_LOAD_PATH = File.join(File.dirname(__FILE__), 'fixtures')
ActionController::Base.view_paths = FIXTURE_LOAD_PATH
