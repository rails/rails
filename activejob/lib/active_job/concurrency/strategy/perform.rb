# frozen_string_literal: true

module ActiveJob
  module Concurrency
    module Strategy
      class Perform < Strategy::Base
        def enqueue_limit?
          false
        end

        def perform_limit?
          true
        end
      end
    end
  end
end
