# frozen_string_literal: true

require "active_job/test_helper"
require "active_job/continuation"

module ActiveJob
  class Continuation
    # Test helper for ActiveJob::Continuable jobs.
    #
    module TestHelper
      include ::ActiveJob::TestHelper

      # Interrupt a job during a step.
      #
      #  class MyJob < ApplicationJob
      #    include ActiveJob::Continuable
      #
      #    cattr_accessor :items, default: []
      #    def perform
      #      step :my_step, start: 1 do |step|
      #        (step.cursor..10).each do |i|
      #          items << i
      #          step.advance!
      #        end
      #      end
      #    end
      #  end
      #
      #  test "interrupt job during step" do
      #    MyJob.perform_later
      #    interrupt_job_during_step(MyJob, :my_step, cursor: 6) { perform_enqueued_jobs }
      #    assert_equal [1, 2, 3, 4, 5], MyJob.items
      #    perform_enqueued_jobs
      #    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], MyJob.items
      #  end
      def interrupt_job_during_step(job, step, cursor: nil, &block)
        require_active_job_test_adapter!("interrupt_job_during_step")
        queue_adapter.with(stopping: ->() { during_step?(job, step, cursor: cursor) }, &block)
      end

      # Interrupt a job after a step.
      #
      # Note that there's no checkpoint after the final step so it won't be interrupted.
      #
      #  class MyJob < ApplicationJob
      #    include ActiveJob::Continuable
      #
      #    cattr_accessor :items, default: []
      #
      #    def perform
      #      step :step_one { items << 1 }
      #      step :step_two { items << 2 }
      #      step :step_three { items << 3 }
      #      step :step_four { items << 4 }
      #    end
      #  end
      #
      #  test "interrupt job after step" do
      #    MyJob.perform_later
      #    interrupt_job_after_step(MyJob, :step_two) { perform_enqueued_jobs }
      #    assert_equal [1, 2], MyJob.items
      #    perform_enqueued_jobs
      #    assert_equal [1, 2, 3, 4], MyJob.items
      #  end
      def interrupt_job_after_step(job, step, &block)
        require_active_job_test_adapter!("interrupt_job_after_step")
        queue_adapter.with(stopping: ->() { after_step?(job, step) }, &block)
      end

      private
        def continuation_for(klass)
          job = ActiveSupport::ExecutionContext.to_h[:job]
          job.send(:continuation)&.to_h if job && job.is_a?(klass)
        end

        def during_step?(job, step, cursor: nil)
          if (continuation = continuation_for(job))
            continuation["current"] == [ step.to_s, cursor ]
          end
        end

        def after_step?(job, step)
          if (continuation = continuation_for(job))
            continuation["completed"].last == step.to_s && continuation["current"].nil?
          end
        end
    end
  end
end
