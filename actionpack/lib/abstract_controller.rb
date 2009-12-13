require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/module/delegation"

module AbstractController
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Callbacks
  autoload :Helpers
  autoload :Layouts
  autoload :LocalizedCache
  autoload :Logger
  autoload :RenderingController
end
