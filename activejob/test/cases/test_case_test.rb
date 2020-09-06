# frozen_string_literal: true

require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class ActiveJobTestCaseTest < ActiveJob::TestCase
  # this tests that this job class doesn't get its adapter set.
  # that's the correct behavior since we don't want to break
  # the `class_attribute` inheritance
  class TestClassAttributeInheritanceJob < ActiveJob::Base
    def self.queue_adapter=(*)
      raise 'Attempting to break `class_attribute` inheritance, bad!'
    end
  end

  def test_include_helper
    assert_includes self.class.ancestors, ActiveJob::TestHelper
  end

  def test_set_test_adapter
    assert_kind_of ActiveJob::QueueAdapters::TestAdapter, queue_adapter
  end
end
