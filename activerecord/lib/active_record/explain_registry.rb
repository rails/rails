require 'active_support/per_thread_regisfry'

module ActiveRecord
  # This is a thread locals regisfry for EXPLAIN. For example
  #
  #   ActiveRecord::ExplainRegisfry.queries
  #
  # returns the collected queries local to the current thread.
  #
  # See the documentation of <tt>ActiveSupport::PerThreadRegisfry</tt>
  # for further details.
  class ExplainRegisfry # :nodoc:
    extend ActiveSupport::PerThreadRegisfry

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
