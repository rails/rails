# frozen_string_literal: true

require "helper"
require "jobs/hello_job"
require "jobs/logging_job"
require "jobs/nested_job"

class ActiveJobTestCaseTest < ActiveJob::TestCase
  # this tests that this job class doesn't get its adapter set.
  # that's the correct behavior since we don't want to break
  # the `class_attribute` inheritance
  class TestClassAttributeInheritanceJob < ActiveJob::Base
    def self.queue_adapter=(*)
      raise "Attempting to break `class_attribute` inheritance, bad!"
    end
  end

  def test_include_helper
    assert_includes self.class.ancestors, ActiveJob::TestHelper
  end

  def test_set_test_adapter
    # The queue adapter the job uses depends on the Active Job config.
    # See https://github.com/rails/rails/pull/48585 for logic.
    expected = case ActiveJob::Base.queue_adapter_name.to_sym
               when :test
                 ActiveJob::QueueAdapters::TestAdapter
               when :inline
                 ActiveJob::QueueAdapters::InlineAdapter
               when :async
                 ActiveJob::QueueAdapters::AsyncAdapter
               when :backburner
                 ActiveJob::QueueAdapters::BackburnerAdapter
               when :delayed_job
                 ActiveJob::QueueAdapters::DelayedJobAdapter
               when :queue_classic
                 ActiveJob::QueueAdapters::QueueClassicAdapter
               when :resque
                 ActiveJob::QueueAdapters::ResqueAdapter
               when :sidekiq
                 ActiveJob::QueueAdapters::SidekiqAdapter
               when :sneakers
                 ActiveJob::QueueAdapters::SneakersAdapter
               when :sucker_punch
                 ActiveJob::QueueAdapters::SuckerPunchAdapter
               else
                 raise NotImplementedError.new
    end

    assert_kind_of expected, queue_adapter
  end

  def test_does_not_perform_enqueued_jobs_by_default
    assert_nil ActiveJob::QueueAdapters::TestAdapter.new.perform_enqueued_jobs
  end
end
