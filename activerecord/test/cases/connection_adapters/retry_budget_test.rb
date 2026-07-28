# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class RetryBudgetTest < ActiveRecord::TestCase
      test "is exhausted by consumption" do
        budget = RetryBudget.new(retries: 1, deadline: nil, reconnectable: true)

        assert_predicate budget, :available?
        assert budget.consume
        assert_equal 1, budget.attempts_used
        assert_not_predicate budget, :available?
        assert_not budget.consume
      end

      test "is exhausted by deadline" do
        expired = RetryBudget.new(
          retries: 1,
          deadline: Process.clock_gettime(Process::CLOCK_MONOTONIC) - 1,
          reconnectable: true
        )

        assert_predicate expired, :expired?
        assert_not_predicate expired, :available?
        assert_not expired.consume
      end
    end
  end
end
