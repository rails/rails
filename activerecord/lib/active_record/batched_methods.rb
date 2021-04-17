# frozen_string_literal: true

require "active_record/batched_methods/batch"
require "active_record/batched_methods/method"

module ActiveRecord::BatchedMethods
  extend ActiveSupport::Concern

  class_methods do
    # Define a batched method. This method will be available on instances
    # of this class and return auto-memoized results.
    def batch_method(name, batch_size: nil, &block)
      batched_methods[name] = Method.new(block, batch_size: batch_size)

      define_method(name) do |*args|
        batched_method_batch.result_for(name, args, self)
      end
    end

    def batched_methods # :nodoc:
      @batched_methods ||= {}
    end
  end

  # Associate this instance with a batch which is will use for batched loading
  def batched_method_batch=(batch) # :nodoc:
    @batched_method_batch = batch
    batch.add(self)
  end

  private
    # Get the current batch, returning a batch of one element if not set
    def batched_method_batch
      return @batched_method_batch if @batched_method_batch
      self.batched_method_batch = Batch.new(self.class)
    end
end
