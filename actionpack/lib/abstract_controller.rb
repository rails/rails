require "active_support/core_ext/module/attr_internal"
require "active_support/core_ext/module/delegation"

module AbstractController
  autoload :Base,               "abstract_controller/base"
  autoload :Benchmarker,        "abstract_controller/benchmarker"
  autoload :Callbacks,          "abstract_controller/callbacks"
  autoload :Helpers,            "abstract_controller/helpers"
  autoload :Layouts,            "abstract_controller/layouts"
  autoload :Logger,             "abstract_controller/logger"
  autoload :Renderer,           "abstract_controller/renderer"
  # === Exceptions
  autoload :ActionNotFound,     "abstract_controller/exceptions"
  autoload :DoubleRenderError,  "abstract_controller/exceptions"
  autoload :Error,              "abstract_controller/exceptions"
end
