activesupport_path = File.expand_path('../../../activesupport/lib', __FILE__)
$:.unshift(activesupport_path) if File.directory?(activesupport_path) && !$:.include?(activesupport_path)

require 'active_support/ruby/shim'
require 'active_support/dependencies/autoload'
require 'active_support/core_ext/module/attr_internal'
require 'active_support/core_ext/module/delegation'

module AbstractController
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Callbacks
  autoload :Collector
  autoload :Compatibility
  autoload :Helpers
  autoload :Layouts
  autoload :LocalizedCache
  autoload :Logger
  autoload :Rendering
  autoload :Translation
end
