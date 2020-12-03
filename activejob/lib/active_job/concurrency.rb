# frozen_string_literal: true

module ActiveJob
  module Concurrency
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    autoload :Strategy

    DEFAULT_TIMEOUT = 120

    included do
      class_attribute :_concurrency_enqueue_limit, instance_accessor: false
      class_attribute :_concurrency_perform_limit, instance_accessor: false
      class_attribute :_concurrency_keys, instance_accessor: false
      class_attribute :_concurrency_timeout, instance_accessor: false
      class_attribute :_concurrency_strategy, instance_accessor: false
    end

    module ClassMethods
      def concurrency_enqueue_limit
        self._concurrency_enqueue_limit
      end

      def concurrency_perform_limit
        self._concurrency_perform_limit
      end

      def concurrency_keys
        self._concurrency_keys
      end

      def concurrency_timeout
        self._concurrency_timeout
      end

      def concurrency_strategy
        self._concurrency_strategy
      end

      def enqueue_exclusively_with(limit: 1, keys: [], timeout: DEFAULT_TIMEOUT)
        self._concurrency_enqueue_limit = limit
        self._concurrency_perform_limit = 0
        self._concurrency_keys = keys
        self._concurrency_timeout = timeout
        self._concurrency_strategy = Strategy::ENQUEUE_STRATEGY
      end

      def perform_exclusively_with(limit: 1, keys: [], timeout: DEFAULT_TIMEOUT)
        self._concurrency_perform_limit = limit
        self._concurrency_enqueue_limit = 0
        self._concurrency_keys = keys
        self._concurrency_timeout = timeout
        self._concurrency_strategy = Strategy::PERFORM_STRATEGY
      end

      def enqueue_and_perform_exclusively_with(enqueue_limit: 1, perform_limit: 1, keys: [], timeout: DEFAULT_TIMEOUT)
        self._concurrency_enqueue_limit = enqueue_limit
        self._concurrency_perform_limit = perform_limit
        self._concurrency_keys = keys
        self._concurrency_timeout = timeout
        self._concurrency_strategy = Strategy::ENQUEUE_AND_PERFORM_STRATEGY
      end

      def exclusively_with(limit: 1, keys: [], timeout: DEFAULT_TIMEOUT)
        self._concurrency_enqueue_limit = limit
        self._concurrency_perform_limit = limit
        self._concurrency_keys = keys
        self._concurrency_timeout = timeout
        self._concurrency_strategy = Strategy::END_TO_END_STRATEGY
      end
    end

    attr_writer :concurrency_enqueue_limit, :concurrency_perform_limit, :concurrency_key, :concurrency_timeout, :concurrency_strategy

    def serialize
      super.merge(
        "concurrency_enqueue_limit" => concurrency_enqueue_limit,
        "concurrency_perform_limit" => concurrency_perform_limit,
        "concurrency_key"           => concurrency_key,
        "concurrency_timeout"       => concurrency_timeout,
        "concurrency_strategy"      => concurrency_strategy
      )
    end

    def deserialize(job_data)
      super
      self.concurrency_enqueue_limit   = job_data["concurrency_enqueue_limit"]
      self.concurrency_perform_limit   = job_data["concurrency_perform_limit"]
      self.concurrency_key             = job_data["concurrency_key"]
      self.concurrency_timeout         = job_data["concurrency_timeout"]
      self.concurrency_strategy        = job_data["concurrency_strategy"]
    end

    def concurrency_enqueue_limit
      self.class.concurrency_enqueue_limit
    end

    def concurrency_perform_limit
      self.class.concurrency_perform_limit
    end

    def concurrency_keys
      self.class.concurrency_keys
    end

    def concurrency_timeout
      self.class.concurrency_timeout
    end

    def concurrency_strategy
      self.class.concurrency_strategy
    end

    def concurrency_strategy_instance
      Strategy.new(self)
    end

    def concurrency_reached?
      concurrency_strategy_information = concurrency_strategy_instance

      return false unless concurrency_strategy_information

      if concurrency_strategy_information.enqueue_limit?
        self.class.queue_adapter.concurrency_reached?(self)
      end
    end

    def concurrency_key
      keys = self.class.concurrency_keys
      return unless keys

      "#{self.class}:#{arguments[0].dig(*keys)}"
    end

    def clear_concurrency
      self.class.queue_adapter.clear_concurrency(self) if concurrency_strategy_instance.any?
    end
  end
end
