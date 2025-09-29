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
end
