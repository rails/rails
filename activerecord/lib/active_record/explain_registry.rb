require 'active_support/per_thread_registry'

module ActiveRecord
  # This is a thread locals registry for EXPLAIN. For example
  #
  #   ActiveRecord::ExplainRegistry.queries
  #
  # returns the collected queries local to the current thread.
  #
  # See the documentation of ActiveSupport::PerThreadRegistry
  # for further details.
  class ExplainRegistry # :nodoc:
    extend ActiveSupport::PerThreadRegistry

    attr_accessor :queries, :collect

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
