module Rails
  module Rack
    autoload :Debugger,      "rails/rack/debugger"   if RUBY_VERSION < '2.0.0'
    autoload :Logger,        "rails/rack/logger"
  end
end
