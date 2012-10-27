require 'abstract_unit'
require 'active_support/queueing'

class SynchronousQueueTest < ActiveSupport::TestCase
  class Job
    attr_reader :ran
    def run; @ran = true end
  end

  class ExceptionRaisingJob
    def run; raise end
  end

  def setup
    @queue = ActiveSupport::SynchronousQueue.new
  end

  def test_runs_jobs_immediately
    begin
      $stderr, old_stderr = StringIO.new, $stderr

      job = Job.new
      @queue.push job
      assert job.ran

      @queue.push ExceptionRaisingJob.new
      assert_match 'Job Error', $stderr.string
    ensure
      $stderr = old_stderr
    end
  end
end
