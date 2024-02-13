# frozen_string_literal: true

require "active_support/rescuable"

module ActiveJob
  # = Active Job \Execution
  #
  # Provides methods to execute jobs immediately, and wraps job execution so
  # that exceptions configured with
  # {rescue_from}[rdoc-ref:ActiveSupport::Rescuable::ClassMethods#rescue_from]
  # are handled.
  module Execution
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable

    # Includes methods for executing and performing jobs instantly.
    module ClassMethods
      # Performs the job immediately.
      #
      #   MyJob.perform_now("mike")
      #
      def perform_now(...)
        job_or_instantiate(...).perform_now
      end

      def execute(job_data) # :nodoc:
        ActiveJob::Callbacks.run_callbacks(:execute) do
          job = deserialize(job_data)
          job.perform_now
        end
      end
    end

    # Performs the job immediately. The job is not sent to the queuing adapter
    # but directly executed by blocking the execution of others until it's finished.
    # +perform_now+ returns the value of your job's +perform+ method.
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
    rescue Exception => exception
      handled = rescue_with_handler(exception)
      return handled if handled

      run_after_discard_procs(exception)
      raise
    end

    def perform(*)
      fail NotImplementedError
    end

    private
      def _perform_job
        ActiveSupport::ExecutionContext[:job] = self
        run_callbacks :perform do
          perform(*arguments)
        end
      end
  end
end
