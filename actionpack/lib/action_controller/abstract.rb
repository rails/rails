require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/module/delegation"

module AbstractController
  autoload :Base,               "action_controller/abstract/base"
  autoload :Benchmarker,        "action_controller/abstract/benchmarker"
  autoload :Callbacks,          "action_controller/abstract/callbacks"
  autoload :Helpers,            "action_controller/abstract/helpers"
  autoload :Layouts,            "action_controller/abstract/layouts"
  autoload :Logger,             "action_controller/abstract/logger"
  autoload :Renderer,           "action_controller/abstract/renderer"
  # === Exceptions
  autoload :ActionNotFound,     "action_controller/abstract/exceptions"
  autoload :DoubleRenderError,  "action_controller/abstract/exceptions"
  autoload :Error,              "action_controller/abstract/exceptions"
end
