# frozen_string_literal: true

# :markup: markdown

require "active_support/benchmarkable"

module AbstractController
  module Logger # :nodoc:
    extend ActiveSupport::Concern

    included do
      # The logger is read on every request, so read it with OrderedOptions#[]
      # rather than through the much slower OrderedOptions#method_missing.
      def self.logger
        config[:logger]
      end
      singleton_class.delegate :logger=, to: :config

      def logger
        config[:logger]
      end
      delegate :logger=, to: :config
      include ActiveSupport::Benchmarkable
    end
  end
end
