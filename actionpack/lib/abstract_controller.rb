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

  # === Exceptions
  autoload_at "abstract_controller/exceptions" do
    autoload :ActionNotFound
    autoload :DoubleRenderError
    autoload :Error
  end
end
