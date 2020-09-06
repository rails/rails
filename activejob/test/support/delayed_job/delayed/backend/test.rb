# frozen_string_literal: true

# copied from https://github.com/collectiveidea/delayed_job/blob/master/spec/delayed/backend/test.rb
require 'ostruct'

# An in-memory backend suitable only for testing. Tries to behave as if it were an ORM.
module Delayed
  module Backend
    module Test
      class Job
        attr_accessor :id
        attr_accessor :priority
        attr_accessor :attempts
        attr_accessor :handler
        attr_accessor :last_error
        attr_accessor :run_at
        attr_accessor :locked_at
        attr_accessor :locked_by
        attr_accessor :failed_at
        attr_accessor :queue

        include Delayed::Backend::Base

        cattr_accessor :id, default: 0, instance_accessor: false

        def initialize(hash = {})
          self.attempts = 0
          self.priority = 0
          self.id = (self.class.id += 1)
          hash.each { |k, v| send(:"#{k}=", v) }
        end

        @jobs = []
        def self.all
          @jobs
        end

        def self.count
          all.size
        end

        def self.delete_all
          all.clear
        end

        def self.create(attrs = {})
          new(attrs).tap(&:save)
        end

        def self.create!(*args); create(*args); end

        def self.clear_locks!(worker_name)
          all.select { |j| j.locked_by == worker_name }.each { |j| j.locked_by = nil; j.locked_at = nil }
        end

        # Find a few candidate jobs to run (in case some immediately get locked by others).
        def self.find_available(worker_name, limit = 5, max_run_time = Worker.max_run_time)
          jobs = all.select do |j|
            j.run_at <= db_time_now &&
            (j.locked_at.nil? || j.locked_at < db_time_now - max_run_time || j.locked_by == worker_name) &&
            !j.failed?
          end

          jobs = jobs.select { |j| Worker.queues.include?(j.queue) }   if Worker.queues.any?
          jobs = jobs.select { |j| j.priority >= Worker.min_priority } if Worker.min_priority
          jobs = jobs.select { |j| j.priority <= Worker.max_priority } if Worker.max_priority
          jobs.sort_by { |j| [j.priority, j.run_at] }[0..limit - 1]
        end

        # Lock this job for this worker.
        # Returns true if we have the lock, false otherwise.
        def lock_exclusively!(max_run_time, worker)
          now = self.class.db_time_now
          if locked_by != worker
            # We don't own this job so we will update the locked_by name and the locked_at
            self.locked_at = now
            self.locked_by = worker
          end

          true
        end

        def self.db_time_now
          Time.current
        end

        def update_attributes(attrs = {})
          attrs.each { |k, v| send(:"#{k}=", v) }
          save
        end

        def destroy
          self.class.all.delete(self)
        end

        def save
          self.run_at ||= Time.current

          self.class.all << self unless self.class.all.include?(self)
          true
        end

        def save!; save; end

        def reload
          reset
          self
        end
      end
    end
  end
end
