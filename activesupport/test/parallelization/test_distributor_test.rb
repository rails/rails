# frozen_string_literal: true

require_relative "../abstract_unit"

class TestDistributorTest < ActiveSupport::TestCase
  test "distributes tests round-robin as they arrive" do
    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(
      worker_count: 2
    )

    # Add tests and they should be distributed immediately
    distributor.add_test(["Test1", "test_a", nil])
    distributor.add_test(["Test2", "test_b", nil])
    distributor.add_test(["Test3", "test_c", nil])

    # Worker 0 should get Test1 and Test3 (indexes 0 and 2)
    test1 = distributor.take(worker_id: 0)
    assert_equal "Test1", test1[0]

    test3 = distributor.take(worker_id: 0)
    assert_equal "Test3", test3[0]

    # Worker 1 should get Test2 (index 1)
    test2 = distributor.take(worker_id: 1)
    assert_equal "Test2", test2[0]
  end

  test "interrupt clears pending tests" do
    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(
      worker_count: 2
    )

    distributor.add_test(["FooTest", "test_a", nil])
    distributor.add_test(["BarTest", "test_b", nil])
    assert distributor.pending?

    distributor.interrupt
    assert_not distributor.pending?
  end

  test "close stops accepting tests and closes queues" do
    distributor = ActiveSupport::Testing::Parallelization::RoundRobinDistributor.new(
      worker_count: 2
    )

    distributor.add_test(["FooTest", "test_a", nil])
    distributor.add_test(["BarTest", "test_b", nil])

    distributor.close

    # After close, adding tests should be ignored
    distributor.add_test(["Test3", "test_c", nil])

    # Can still drain queued tests
    test1 = distributor.take(worker_id: 0)
    assert_equal "FooTest", test1[0]

    # Worker 1 gets its test
    test2 = distributor.take(worker_id: 1)
    assert_equal "BarTest", test2[0]

    # No Test3 because it was added after close
    assert_nil distributor.take(worker_id: 0)
    assert_nil distributor.take(worker_id: 1)
  end

  test "work stealing distributor steals work from other workers when queue empty" do
    distributor = ActiveSupport::Testing::Parallelization::RoundRobinWorkStealingDistributor.new(
      worker_count: 2
    )

    # Add 3 tests - with round-robin, worker 0 gets Test1 and Test3, worker 1 gets Test2
    distributor.add_test(["Test1", "test_a", nil])
    distributor.add_test(["Test2", "test_b", nil])
    distributor.add_test(["Test3", "test_c", nil])

    # Close to signal no more tests coming
    distributor.close

    # Worker 0 takes its tests
    test1 = distributor.take(worker_id: 0)
    assert_equal "Test1", test1[0]
    test3 = distributor.take(worker_id: 0)
    assert_equal "Test3", test3[0]

    # Worker 1 takes its test
    test2 = distributor.take(worker_id: 1)
    assert_equal "Test2", test2[0]

    # Now both queues are empty and closed - workers get nil
    assert_nil distributor.take(worker_id: 0)
    assert_nil distributor.take(worker_id: 1)
  end

  test "work stealing distributor returns nil when no work available anywhere" do
    distributor = ActiveSupport::Testing::Parallelization::RoundRobinWorkStealingDistributor.new(
      worker_count: 2
    )

    distributor.add_test(["Test1", "test_a", nil])
    distributor.add_test(["Test2", "test_b", nil])

    # Close to signal no more tests
    distributor.close

    # Drain all tests
    distributor.take(worker_id: 0)  # Takes Test1
    distributor.take(worker_id: 1)  # Takes Test2

    # No work left anywhere, queues are closed
    assert_nil distributor.take(worker_id: 0)
    assert_nil distributor.take(worker_id: 1)
  end

  test "SharedQueueDistributor distributes tests to any worker" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new

    distributor.add_test(["Test1", "test_a", nil])
    distributor.add_test(["Test2", "test_b", nil])

    # Any worker can get any test
    test1 = distributor.take(worker_id: 0)
    test2 = distributor.take(worker_id: 1)

    assert_not_nil test1
    assert_not_nil test2
    assert_not_equal test1[0], test2[0]
  end

  test "SharedQueueDistributor pending? reflects queue state" do
    distributor = ActiveSupport::Testing::Parallelization::SharedQueueDistributor.new

    assert_not distributor.pending?

    distributor.add_test(["Test1", "test_a", nil])
    assert distributor.pending?

    distributor.take(worker_id: 0)
    assert_not distributor.pending?
  end
end
