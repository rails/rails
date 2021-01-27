# typed: false
# frozen_string_literal: true
module ActiveRecord
  module AfterCommitJobEnqueue
    extend ActiveSupport::Concern

    included do |base|
      base.after_commit(:enqueue_waiting_jobs)
    end

    def enqueue_transactional_job(job, options)
      waiting_jobs.push([job, options])
    end

    private

    def waiting_jobs
      @waiting_jobs ||= []
    end

    def enqueue_waiting_jobs
      waiting_jobs.uniq.each do |job|
        job[0]&.perform_later(**job[1])
      end
    end
  end
end
