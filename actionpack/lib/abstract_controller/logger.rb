require "active_support/core_ext/logger"
require "active_support/benchmarkable"

module AbstractController
  module Logger
    extend ActiveSupport::Concern

    included do
      config_accessor :logger
      extend ActiveSupport::Benchmarkable
    end
  end
end
