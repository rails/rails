# frozen_string_literal: true

module ActiveJob
  module Concurrency
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    autoload :Limit

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
        self._concurrency_limit = Limit.new(limit)
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

    def concurrency_limit
      @concurrency_limit ||= self.class.concurrency_limit
    end

    def concurrency_reached?
      return false unless concurrency_limit

      if concurrency_limit.locking? || concurrency_limit.enqueue_limit?
        self.class.queue_adapter.concurrency_reached?(self)
      end
    end

    def concurrency_key
      keys = self.class.concurrency_keys
      "#{self.class}:#{arguments[0].dig(*keys)}"
    end

    def clear_concurrency
      return unless self.class.concurrency_limit
      self.class.queue_adapter.clear_concurrency(self)
    end
  end
end
