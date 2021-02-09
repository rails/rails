# frozen_string_literal: true

module ActiveJob
  module Concurrency
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    module Strategy
      autoload :Base,      "active_job/concurrency/strategy/base"
      autoload :Exclusive, "active_job/concurrency/strategy/exclusive"
      autoload :Enqueue,   "active_job/concurrency/strategy/enqueue"
      autoload :Perform,   "active_job/concurrency/strategy/perform"
    end

    DEFAULT_TIMEOUT = 120

    included do
      class_attribute :_concurrency_strategies, instance_accessor: false, instance_predicate: false, default: []
    end

    module ClassMethods
      def concurrency_strategies
        self._concurrency_strategies
      end

      def exclusively_with(limit: 1, keys: [], prefix: "", timeout: DEFAULT_TIMEOUT)
        self._concurrency_strategies += [Strategy::Exclusive.new(limit, keys, prefix, timeout)]
      end

      def enqueue_exclusively_with(limit: 1, keys: [], prefix: "", timeout: DEFAULT_TIMEOUT)
        self._concurrency_strategies += [Strategy::Enqueue.new(limit, keys, prefix, timeout)]
      end

      def perform_exclusively_with(limit: 1, keys: [], prefix: "", timeout: DEFAULT_TIMEOUT)
        self._concurrency_strategies += [Strategy::Perform.new(limit, keys, prefix, timeout)]
      end
    end

    attr_writer :concurrency

    def serialize
      super.merge(
        "concurrency" => concurrency_strategies.map do |concurrency_strategy|
          {
            "strategy" => concurrency_strategy.name,
            "limit"    => concurrency_strategy.limit,
            "keys"     => concurrency_strategy.keys,
            "prefix"   => concurrency_strategy.prefix,
            "timeout"  => concurrency_strategy.timeout,
          }
        end
      )
    end

    def deserialize(job_data)
      super

      self.concurrency = job_data["concurrency"].map do |concurrency|
        concurrency["strategy"].constantize.new(concurrency["limit"], concurrency["keys"], concurrency["prefix"], concurrency["timeout"])
      end if job_data["concurrency"].present?
    end

    def concurrency_strategies
      self.class.concurrency_strategies
    end

    def concurrency_reached?
      concurrency_strategies.each do |concurrency_strategy|
        next unless concurrency_strategy.enqueue_limit?

        return true if self.class.queue_adapter.concurrency_reached?(concurrency_strategy, self)
      end

      false
    end

    def clear_concurrency
      concurrency_strategies.each do |concurrency_strategy|
        self.class.queue_adapter.clear_concurrency(concurrency_strategy, self)
      end
    end
  end
end
