# frozen_string_literal: true

module ActiveJob
  # Provides general behavior that will be included into every Active Job
  # object that inherits from ActiveJob::Base.
  module Concurrency
    extend ActiveSupport::Concern

    included do
      class_attribute :_concurrency_limit, instance_accessor: false
      class_attribute :_concurrency_keys, instance_accessor: false
      class_attribute :_concurrency_timeout, instance_accessor: false
    end

    module ClassMethods
      def concurrency_limit
        self._concurrency_limit
      end

      def concurrency_keys
        self._concurrency_keys
      end

      def concurrency_timeout
        self._concurrency_timeout
      end

      def concurrency(limit:, keys: [], timeout: 120)
        self._concurrency_limit = limit
        self._concurrency_keys = keys
        self._concurrency_timeout = timeout
      end
    end

    attr_accessor :concurrency_limit

    attr_accessor :concurrency_keys

    attr_accessor :concurrency_timeout

    def serialize
      super.merge(
        "concurrency_limit"   => concurrency_limit,
        "concurrency_keys"    => concurrency_keys,
        "concurrency_timeout" => concurrency_timeout
      )
    end

    def deserialize(job_data)
      super
      self.concurrency_limit   = job_data["concurrency_limit"]
      self.concurrency_keys    = job_data["concurrency_keys"]
      self.concurrency_timeout = job_data["concurrency_timeout"]
    end

    def clear_concurrency
      self.class.queue_adapter.clear_concurrency(self)
    end
  end
end
