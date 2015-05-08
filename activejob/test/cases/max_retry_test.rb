require 'helper'
require 'jobs/hello_job'
require 'jobs/logging_job'
require 'jobs/nested_job'

class MaxRetryTest < ActiveSupport::TestCase
  test 'max retry from base' do
    assert_equal nil, HelloJob.max_retry
  end

  test 'uses given max retry job' do
    original_max_retry = HelloJob.max_retry

    begin
      HelloJob.max_retry 5
      assert_equal 5, HelloJob.new.max_retry
    ensure
      HelloJob.max_retry = original_max_retry
    end
  end

  test 'not allows a blank max_retry' do
    original_max_retry = HelloJob.max_retry

    begin
      HelloJob.max_retry ''
      assert_equal nil, HelloJob.max_retry
    ensure
      HelloJob.max_retry = original_max_retry
    end
  end

  test 'uses given string for max retry job' do
    original_max_retry = HelloJob.max_retry

    begin
      HelloJob.max_retry '5'
      assert_equal 5, HelloJob.new.max_retry
    ensure
      HelloJob.max_retry = original_max_retry
    end
  end

  test 'evals block given to max_retry to determine max retries' do
    original_max_retry = HelloJob.max_retry

    begin
      HelloJob.max_retry { 2 }
      assert_equal 2, HelloJob.new.max_retry
    ensure
      HelloJob.max_retry = original_max_retry
    end
  end

  test 'can use arguments to determine max retry in max_retry block' do
    original_max_retry = HelloJob.max_retry

    begin
      HelloJob.max_retry { self.arguments.first=='a' ? 1 : 3 }
      assert_equal 1, HelloJob.new('a').max_retry
      assert_equal 3, HelloJob.new('b').max_retry
    ensure
      HelloJob.max_retry = original_max_retry
    end
  end

end
