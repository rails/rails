# frozen_string_literal: true

# :markup: markdown
module Rails
  module Rack
    autoload :Logger, "rails/rack/logger"
    autoload :SilenceRequest, "rails/rack/silence_request"
  end
end
