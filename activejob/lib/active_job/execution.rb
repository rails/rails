# frozen_string_literal: true

require "active_support/rescuable"
require "active_job/arguments"

module ActiveJob
  module Execution
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    # Includes methods for executing and performing jobs instantly.
    module ClassMethods
      # Performs the job immediately.
      #
      #   MyJob.perform_now("mike")
      #
      def perform_now(*args)
        job_or_instantiate(*args).perform_now
      end
      ruby2_keywords(:perform_now) if respond_to?(:ruby2_keywords, true)

      def execute(job_data) #:nodoc:
        ActiveJob::Callbacks.run_callbacks(:execute) do
          job = deserialize(job_data)
          job.perform_now
        end
      end
    end

    # Performs the job immediately. The job is not sent to the queuing adapter
    # but directly executed by blocking the execution of others until it's finished.
    # `perform_now` returns the value of your job's `perform` method.
    #
    #   class MyJob < ActiveJob::Base
    #     def perform
    #       "Hello World!"
    #     end
    #   end
    #
    #   puts MyJob.new(*args).perform_now # => "Hello World!"
    def perform_now
      # Guard against jobs that were persisted before we started counting executions by zeroing out nil counters
      self.executions = (executions || 0) + 1

      deserialize_arguments_if_needed

      _perform_job
    rescue => exception
      rescue_with_handler(exception) || raise
    end

    def perform(*)
      fail NotImplementedError
    end

    private
      def _perform_job
        run_callbacks :perform do
          perform(*arguments)
        end
      end
  end
end
