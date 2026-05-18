# frozen_string_literal: true

#--
# Copyright (c) David Heinemeier Hansson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require "active_support"
require "active_support/rails"
require "active_job/version"
require "active_job/deprecator"
require "global_id"

# :markup: markdown
# :include: ../README.md
module ActiveJob
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :QueueAdapters
  autoload :Arguments
  autoload :Attributes
  autoload :DeserializationError, "active_job/arguments"
  autoload :SerializationError, "active_job/arguments"
  autoload :UnknownJobClassError, "active_job/core"
  autoload :EnqueueAfterTransactionCommit

  eager_autoload do
    autoload :Continuable
    autoload :Continuation
    autoload :Serializers
    autoload :ConfiguredJob
  end

  autoload :TestCase
  autoload :TestHelper

  ##
  # :singleton-method: verbose_enqueue_logs
  #
  # Specifies if the methods calling background job enqueue should be logged below
  # their relevant enqueue log lines. Defaults to false.
  singleton_class.attr_accessor :verbose_enqueue_logs
  self.verbose_enqueue_logs = false

  # Push many jobs onto the queue at once without running enqueue callbacks.
  # Queue adapters may communicate the enqueue status of each job by setting
  # successfully_enqueued and/or enqueue_error on the passed-in job instances.
  def self.perform_all_later(*jobs)
    jobs.flatten!
    jobs.group_by(&:queue_adapter).each do |queue_adapter, adapter_jobs|
      instrument_enqueue_all(queue_adapter, adapter_jobs) do
        if queue_adapter.respond_to?(:enqueue_all)
          queue_adapter.enqueue_all(adapter_jobs)
        else
          adapter_jobs.each do |job|
            job.successfully_enqueued = false
            if job.scheduled_at
              queue_adapter.enqueue_at(job, job.scheduled_at.to_f)
            else
              queue_adapter.enqueue(job)
            end
            job.successfully_enqueued = true
          rescue EnqueueError => e
            job.enqueue_error = e
          end
          adapter_jobs.count(&:successfully_enqueued?)
        end
      end
    end
    nil
  end
end
