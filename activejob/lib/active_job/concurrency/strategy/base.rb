# frozen_string_literal: true

module ActiveJob
  module Concurrency
    module Strategy
      class Base
        attr_reader :limit, :keys, :prefix, :timeout

        def initialize(limit, keys, prefix, timeout)
          @limit = limit
          @keys = Array(keys)
          @prefix = prefix
          @timeout = timeout
        end

        def build_key(job)
          if keys.any?
            "#{prefix_key(job)}:#{extract_keys_from_job_arguments(job)}"
          else
            prefix_key(job).to_s
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

        private
          def extract_keys_from_job_arguments(job)
            job.arguments[0]&.dig(*keys)
          end

          def prefix_key(job)
            prefix.present? ? prefix : job.class
          end
      end
    end
  end
end
