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

      def execute(job_data) #:nodoc:
        ActiveJob::Callbacks.run_callbacks(:execute) do
          job = deserialize(job_data)
          job.perform_now
        end
      end
    end

    # Performs the job immediately. The job is not sent to the queueing adapter
    # but directly executed by blocking the execution of others until it's finished.
    #
    #   MyJob.new(*args).perform_now
    def perform_now
      # Guard against jobs that were persisted before we started counting executions by zeroing out nil counters
      self.executions = (executions || 0) + 1

      deserialize_arguments_if_needed
      run_callbacks :perform do
        perform(*arguments)
      end
    rescue => exception
      rescue_with_handler(exception) || raise
    ensure
      if locking?
        clear_lock
      end
    end

    def perform(*)
      fail NotImplementedError
    end
  end
end
