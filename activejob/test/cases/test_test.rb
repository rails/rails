# encoding: utf-8
require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class ActiveJobTestCaseTest < ActiveJob::TestCase
  tests HelloJob

  def test_set_job_class_manual
    assert_equal HelloJob, self.class.job_class
  end
end

class CrazySymbolNameJobTest < ActiveJob::TestCase
  tests :hello_job

  def test_set_job_class_manual_using_symbol
    assert_equal HelloJob, self.class.job_class
  end
end

class CrazyStringNameJobTest < ActiveJob::TestCase
  tests 'hello_job'

  def test_set_job_class_manual_using_string
    assert_equal HelloJob, self.class.job_class
  end
end

class HelloJobTest < ActiveJob::TestCase
  def test_set_job_class_manual
    assert_equal HelloJob, self.class.job_class
  end
end

class CrazyNameJobTest < ActiveJob::TestCase
  def test_determine_default_job_raises_correct_error
    assert_raise(ActiveJob::NonInferrableJobError) do
      self.class.job_class
    end
  end
end
