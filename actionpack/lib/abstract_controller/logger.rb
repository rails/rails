# frozen_string_literal: true

# :markup: markdown

require "active_support/benchmarkable"

module AbstractController
  module Logger # :nodoc:
    extend ActiveSupport::Concern

    included do
      singleton_class.delegate :logger, :logger=, to: :config
      delegate :logger, :logger=, to: :config
      include ActiveSupport::Benchmarkable
    end
  end
end
