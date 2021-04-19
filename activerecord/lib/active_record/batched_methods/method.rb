# frozen_string_literal: true

module ActiveRecord::BatchedMethods
  # Represents the runnable representation of a batched method
  class Method # :nodoc:
    attr_reader :batch_size

    extend Forwardable

    def_delegator :@block, :call

    def initialize(block, batch_size:)
      @block = block
      @batch_size = batch_size
    end
  end
end
