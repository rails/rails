# frozen_string_literal: true

require_relative "../abstract_unit"

class ServerTest < ActiveSupport::TestCase
  def setup
    @worker_pids = []
  end

  def teardown
    @worker_pids.each do |pid|
      unless Process.waitpid(pid, Process::WNOHANG)
        Process.kill("KILL", pid)
        Process.waitpid(pid)
      end
    rescue Errno::ECHILD
      nil
    end
  end

  test "server tracks active workers" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    assert_not server.active_workers?

    server.start_worker("worker-1", 1234)
    assert server.active_workers?

    server.stop_worker("worker-1")
    assert_not server.active_workers?
  end

  test "server removes dead workers" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    server.start_worker("worker-1", 1234)
    server.start_worker("worker-2", 5678)
    assert server.active_workers?

    server.remove_dead_workers([1234])
    assert server.active_workers?  # worker-2 still active

    server.remove_dead_workers([5678])
    assert_not server.active_workers?  # all workers gone
  end

  test "shutdown reports in-flight and queued tests from dead workers" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(worker_count: 2)
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
    reporter = Minitest::StatisticsReporter.new

    6.times { |i| distributor.add_test([self.class, "test_#{i}", reporter]) }
    server.pop(0)
    server.pop(1)

    2.times do |i|
      pid = fork { exit! }
      @worker_pids << pid
      server.start_worker(i, pid)
    end

    Timeout.timeout(5, Minitest::Assertion, "Expected shutdown to not hang") { server.shutdown(@worker_pids) }

    assert_not server.active_workers?
    assert_equal 6, reporter.count
    assert_equal 6, reporter.results.size
    assert_equal (0...6).map { |i| "test_#{i}" }, reporter.results.map(&:name).sort
    assert reporter.results.all?(&:error?)
    assert reporter.results.all? { |result| result.failure.error.message == "result not reported" }
  end

  test "shutdown reports tests when workers exit before registering" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(worker_count: 1)
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
    reporter = Minitest::StatisticsReporter.new
    distributor.add_test([self.class, "test_unstarted", reporter])
    @worker_pids << fork { exit! }

    Timeout.timeout(5, Minitest::Assertion, "Expected shutdown to not hang") { server.shutdown(@worker_pids) }

    assert_equal 1, reporter.count
    assert_equal "test_unstarted", reporter.results.sole.name
    assert reporter.results.sole.error?
  end

  test "shutdown reports remaining tests with work stealing" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    distributors = [
      ActiveSupport::Testing::Parallelization::RoundRobinWorkStealingDistributor.new(worker_count: 2),
      ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new,
    ]

    distributors.each do |distributor|
      server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
      reporter = Minitest::StatisticsReporter.new
      4.times { |i| distributor.add_test([self.class, "test_#{i}", reporter]) }
      server.pop(0)

      worker_pids = 2.times.map { fork { exit! } }
      @worker_pids.concat(worker_pids)
      worker_pids.each { |pid| Process.waitpid(pid) }

      Timeout.timeout(5, Minitest::Assertion, "Expected shutdown to not hang") { server.shutdown(worker_pids) }

      assert_equal 4, reporter.count
      assert_equal %w[test_0 test_1 test_2 test_3], reporter.results.map(&:name).sort
      assert reporter.results.all?(&:error?)
    end
  end

  test "shutdown does not report queued tests discarded by an interrupt" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(worker_count: 1)
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
    reporter = Minitest::StatisticsReporter.new
    distributor.add_test([self.class, "test_running", reporter])
    distributor.add_test([self.class, "test_canceled", reporter])
    server.pop(0)
    server.interrupt
    @worker_pids << fork { exit! }

    Timeout.timeout(5, Minitest::Assertion, "Expected shutdown to not hang") { server.shutdown(@worker_pids) }

    assert_equal 1, reporter.count
    assert_equal "test_running", reporter.results.sole.name
    assert reporter.results.sole.error?
  end

  test "shutdown waits for workers that have not registered yet" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    begin
      distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(worker_count: 1)
      server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)
      reporter = Minitest::StatisticsReporter.new
      distributor.add_test([self.class, "test_slow", reporter])
      reader, writer = IO.pipe
      @worker_pids << fork do
        writer.close
        reader.read
        exit!
      end
      reader.close

      waiting = Queue.new
      waitpid = Process.method(:waitpid)
      Process.stub(:waitpid, ->(*args) { waiting << true; waitpid.call(*args) }) do
        shutdown_thread = Thread.new { server.shutdown(@worker_pids) }
        Timeout.timeout(5) { waiting.pop }

        assert shutdown_thread.alive?
        assert_equal 0, reporter.count

        server.start_worker("late-worker", @worker_pids.first)
        server.pop(0)
        server.record(reporter, Minitest::Result.from(self.class.new("test_slow")))
        writer.close

        Timeout.timeout(5) { shutdown_thread.value }
      ensure
        writer.close unless writer.closed?
        shutdown_thread&.kill&.join
      end

      assert_not server.active_workers?
      assert_equal 1, reporter.count
      assert_empty reporter.results
    ensure
      reader&.close unless reader&.closed?
      writer&.close unless writer&.closed?
    end
  end
end
