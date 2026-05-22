# frozen_string_literal: true

require_relative "abstract_unit"

class ParallelizationTest < ActiveSupport::TestCase
  test "shutdown handles dead workers gracefully" do
    parallelization = ActiveSupport::Testing::Parallelization.new(1)
    parallelization.start

    sleep 0.25

    server = parallelization.instance_variable_get(:@queue_server)
    assert server.active_workers?

    worker_pids = parallelization.instance_variable_get(:@worker_pool)
    Process.kill("KILL", worker_pids.first)
    sleep 0.25

    Timeout.timeout(2.5, Minitest::Assertion, "Expected shutdown to not hang") { parallelization.shutdown }
    assert_not server.active_workers?
  end

  test "shutdown stops the DRb service started in initialize" do
    skip "Process-based parallelization requires fork" unless Process.respond_to?(:fork)

    parallelization = ActiveSupport::Testing::Parallelization.new(1)
    parallelization.start
    parallelization.shutdown

    leaked = Thread.list
      .reject { |t| t == Thread.main }
      .select(&:alive?)
      .select do |t|
        bt = Array(t.backtrace).join("\n")
        bt.include?("drb/drb.rb") && bt.match?(/accept_or_shutdown|main_loop/)
      end

    assert_empty leaked,
      "Expected Parallelization#shutdown to call DRb.stop_service. Leaked:\n" +
      leaked.map { |t| Array(t.backtrace).first(5).join("\n  ") }.join("\n---\n")
  end

  test "shutdown calls run_cleanup_hooks" do
    called = false
    ActiveSupport::Testing::Parallelization.run_cleanup_hook { called = true }

    parallelization = ActiveSupport::Testing::Parallelization.new(1)
    parallelization.start
    parallelization.shutdown

    assert called, "run_cleanup_hooks should be called during shutdown"
  ensure
    ActiveSupport::Testing::Parallelization.class_variable_get(:@@run_cleanup_hooks).pop
  end
end
