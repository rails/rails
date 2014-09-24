require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class ActiveJobTestCaseTest < ActiveJob::TestCase
  def test_include_helper
    assert_includes self.class.ancestors, ActiveJob::TestHelper
  end

  def test_set_test_adapter
    assert_equal ActiveJob::QueueAdapters::TestAdapter, self.queue_adapter
  end
end
