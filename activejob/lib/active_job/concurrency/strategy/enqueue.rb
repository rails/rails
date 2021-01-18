# frozen_string_literal: true

module ActiveJob
  module Concurrency
    module Strategy
      class Enqueue < Strategy::Base
        def enqueue_limit?
          true
        end

        def perform_limit?
          false
        end
      end
    end
  end
end
