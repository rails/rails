module AbstractController
  autoload :Base,           "action_controller/abstract/base"
  autoload :Callbacks,      "action_controller/abstract/callbacks"
  autoload :Helpers,        "action_controller/abstract/helpers"
  autoload :Layouts,        "action_controller/abstract/layouts"
  autoload :Logger,         "action_controller/abstract/logger"
  autoload :Renderer,       "action_controller/abstract/renderer"
  # === Exceptions
  autoload :ActionNotFound, "action_controller/abstract/exceptions"
end