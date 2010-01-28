module Rails
  module Rack
    autoload :Debugger,  "rails/rack/debugger"
    autoload :Logger,    "rails/rack/logger"
    autoload :LogTailer, "rails/rack/log_tailer"
    autoload :Static,    "rails/rack/static"
  end
end
