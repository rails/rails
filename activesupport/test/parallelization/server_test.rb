# frozen_string_literal: true

require_relative "../abstract_unit"

class ServerTest < ActiveSupport::TestCase
  test "server tracks active workers" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new
    server = ActiveSupport::Testing::Parallelization::Server.new(distributor: distributor)

    assert_not server.active_workers?

    server.start_worker("worker-1", 1234)
    assert server.active_workers?

    server.stop_worker("worker-1", 1234)
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
end
