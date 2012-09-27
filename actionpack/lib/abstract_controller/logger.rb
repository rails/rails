require "active_support/benchmarkable"

module AbstractController
  module Logger #:nodoc:
    extend ActiveSupport::Concern

    included do
      config_accessor :logger
      include ActiveSupport::Benchmarkable
    end
  end
end
