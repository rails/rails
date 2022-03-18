# frozen_string_literal: true

require "active_support/core_ext/module/delegation"

module ActiveRecord
  # This is a thread locals registry for EXPLAIN. For example
  #
  #   ActiveRecord::ExplainRegistry.queries
  #
  # returns the collected queries local to the current thread.
  class ExplainRegistry # :nodoc:
    class << self
      delegate :reset, :collect, :collect=, :collect?, :queries, to: :instance

      private
        def instance
          ActiveSupport::IsolatedExecutionState[:active_record_explain_registry] ||= new
        end
    end

    attr_accessor :collect
    attr_reader :queries

    def initialize
      reset
    end

    def collect?
      @collect
    end

    def reset
      @collect = false
      @queries = []
    end
  end
end
