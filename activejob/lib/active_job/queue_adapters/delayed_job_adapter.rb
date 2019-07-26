# frozen_string_literal: true

require "delayed_job"

module ActiveJob
  module Core

    # Override attr_reader in order to defer backend access until it is needed
    def provider_job_id #:nodoc:
      find_provider_job_id
    end

    private

      def scan_backend(job_id_aj) #:nodoc:
        case Delayed::Worker.backend.name
        when "Delayed::Backend::ActiveRecord::Job"
          Delayed::Job.where("handler LIKE '%#{job_id_aj}%'")  # in lieu of Delayed::Job.all
        else
          []
        end
      end

      def find_provider_job_id #:nodoc:
        begin
          job_id_aj = self.job_id
          djs = scan_backend(job_id_aj)
          djs.map do |dj|
            obj = dj.payload_object
            next if obj.blank? || obj.job_data.blank?

            job_id_persisted = obj.job_data["job_id"]
            return dj.id if job_id_persisted == job_id_aj
          end
        rescue
          return nil
        end

        nil
      end

  end
end

module ActiveJob
  module QueueAdapters
    # == Delayed Job adapter for Active Job
    #
    # Delayed::Job (or DJ) encapsulates the common pattern of asynchronously
    # executing longer tasks in the background. Although DJ can have many
    # storage backends, one of the most used is based on Active Record.
    # Read more about Delayed Job {here}[https://github.com/collectiveidea/delayed_job].
    #
    # To use Delayed Job, set the queue_adapter config to +:delayed_job+.
    #
    #   Rails.application.config.active_job.queue_adapter = :delayed_job
    class DelayedJobAdapter
      def enqueue(job) #:nodoc:
        delayed_job = Delayed::Job.enqueue(JobWrapper.new(job.serialize), queue: job.queue_name, priority: job.priority)
        job.provider_job_id = delayed_job.id
        delayed_job
      end

      def enqueue_at(job, timestamp) #:nodoc:
        delayed_job = Delayed::Job.enqueue(JobWrapper.new(job.serialize), queue: job.queue_name, priority: job.priority, run_at: Time.at(timestamp))
        job.provider_job_id = delayed_job.id
        delayed_job
      end

      class JobWrapper #:nodoc:
        attr_accessor :job_data

        def initialize(job_data)
          @job_data = job_data
        end

        def display_name
          "#{job_data['job_class']} [#{job_data['job_id']}] from DelayedJob(#{job_data['queue_name']}) with arguments: #{job_data['arguments']}"
        end

        def perform
          Base.execute(job_data)
        end
      end
    end
  end
end
