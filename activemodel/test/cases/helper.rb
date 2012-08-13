require File.expand_path('../../../../load_paths', __FILE__)
$LOAD_PATH << File.expand_path('../../../test', __FILE__)

require 'config'
require 'active_model'
require 'active_support/core_ext/string/access'

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

require 'minitest/autorun'
