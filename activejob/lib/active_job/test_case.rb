# encoding: utf-8
require 'active_support/test_case'

module ActiveJob
  class NonInferrableJobError < ::StandardError
    def initialize(name)
      super "Unable to determine the job to test from #{name}. " \
                "You'll need to specify it using 'tests YourJob' in your " \
                'test case definition'
    end
  end

  class TestCase < ActiveSupport::TestCase
    module Behavior
      extend ActiveSupport::Concern

      include ActiveSupport::Testing::ConstantLookup
      include ActiveJob::TestHelper

      included do
        class_attribute :_job_class
        setup :initialize_test_adapter
        teardown :restore_previous_adapter
      end

      module ClassMethods
        def tests(job)
          case job
            when String, Symbol
              self._job_class = job.to_s.camelize.constantize
            when Module
              self._job_class = job
            else
              fail NonInferrableJobError.new(job)
          end
        end

        def job_class
          if job = _job_class
            job
          else
            tests determine_default_job(name)
          end
        end

        def determine_default_job(name)
          job = determine_constant_from_test_name(name) do |constant|
            Class === constant && constant < ActiveJob::Base
          end
          fail NonInferrableJobError.new(name) if job.nil?
          job
        end
      end

      protected
        def initialize_test_adapter
          @old_adapter = ActiveJob::Base.queue_adapter
          ActiveJob::Base.queue_adapter = :test
          save_test_adapter_behavior
        end

        def save_test_adapter_behavior
          @old_perform_enqueued_jobs = queue_adapter.perform_enqueued_jobs
          @old_perform_enqueued_at_jobs = queue_adapter.perform_enqueued_at_jobs
        end

        def restore_test_adapter_behavior
          queue_adapter.perform_enqueued_jobs = @old_perform_enqueued_jobs
          queue_adapter.perform_enqueued_at_jobs = @old_perform_enqueued_at_jobs
        end

        def restore_previous_adapter
          restore_test_adapter_behavior
          ActiveJob::Base.queue_adapter = @old_adapter
          ActiveJob::Base.performed_jobs.clear
          ActiveJob::Base.enqueued_jobs.clear
        end

        def perform_enqueued_jobs
          queue_adapter.perform_enqueued_jobs = true
        end

        def perform_enqueued_at_jobs
          queue_adapter.perform_enqueued_at_jobs = true
        end

        def enqueue_jobs
          queue_adapter.perform_enqueued_jobs = false
        end

        def enqueue_at_jobs
          queue_adapter.perform_enqueued_at_jobs = false
        end

      private
        def queue_adapter
          ActiveJob::Base.queue_adapter
        end
    end

    include Behavior
  end
end
