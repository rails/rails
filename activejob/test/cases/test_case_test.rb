require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class ActiveJobTestCaseTest < ActiveJob::TestCase
  # this tests that this job class doesn't get its adapter set.
  # that's the correct behaviour since we don't want to break
  # the `class_attribute` inheritence
  class TestClassAttributeInheritenceJob < ActiveJob::Base
    def self.queue_adapter=(*)
      raise 'Attemping to break `class_attribute` inheritence, bad!'
    end
  end

  def test_include_helper
    assert_includes self.class.ancestors, ActiveJob::TestHelper
  end

  def test_set_test_adapter
    assert_kind_of ActiveJob::QueueAdapters::TestAdapter, self.queue_adapter
  end
end
