# frozen_string_literal: true

module ActiveJob
  module Concurrency
    module Strategy
      class Base
        attr_reader :limit, :keys, :timeout

        def initialize(limit, keys, timeout)
          @limit = limit
          @keys = Array(keys)
          @timeout = timeout
        end

        def build_key(job)
          if keys.any?
            "#{job.class}:#{job.arguments[0].dig(*keys)}"
          else
            job.class.to_s
          end
        end

        def name
          self.class.name
        end

        def enqueue_limit?
          raise NotImplementedError
        end

        def perform_limit?
          raise NotImplementedError
        end
      end
    end
  end
end
