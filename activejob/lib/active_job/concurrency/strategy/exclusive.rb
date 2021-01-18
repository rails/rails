# frozen_string_literal: true

module ActiveJob
  module Concurrency
    module Strategy
      class Exclusive < Strategy::Base
        def enqueue_limit?
          true
        end

        def perform_limit?
          true
        end
      end
    end
  end
end
