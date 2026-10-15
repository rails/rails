# frozen_string_literal: true

# :markup: markdown

require "active_support/benchmarkable"

module AbstractController
  module Logger # :nodoc:
    extend ActiveSupport::Concern

    included do
      include ActiveSupport::Benchmarkable
    end

    # The logger lives in the controller configuration. It is read from the
    # configuration hash directly rather than through `config.logger`, which
    # dispatches through `OrderedOptions#method_missing` and allocates on every
    # call.
    module ClassMethods
      def logger
        config[:logger]
      end

      def logger=(logger)
        config[:logger] = logger
      end
    end

    def logger
      config[:logger]
    end

    def logger=(logger)
      config[:logger] = logger
    end
  end
end
