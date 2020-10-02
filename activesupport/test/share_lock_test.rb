# frozen_string_literal: true

require_relative "abstract_unit"
require "concurrent/atomic/count_down_latch"
require "active_support/concurrency/share_lock"

class ShareLockTest < ActiveSupport::TestCase
  def setup
    @lock = ActiveSupport::Concurrency::ShareLock.new
  end

  def test_reentrancy
    thread = Thread.new do
      @lock.sharing   { @lock.sharing   { } }
      @lock.exclusive { @lock.exclusive { } }
    end
    assert_threads_not_stuck thread
  end

  def test_sharing_doesnt_block
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_latch|
      assert_threads_not_stuck(Thread.new { @lock.sharing { } })
    end
  end

  def test_sharing_blocks_exclusive
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      @lock.exclusive(no_wait: true) { flunk } # polling should fail
      exclusive_thread = Thread.new { @lock.exclusive { } }
      assert_threads_stuck_but_releasable_by_latch exclusive_thread, sharing_thread_release_latch
    end
  end

  def test_exclusive_blocks_sharing
    with_thread_waiting_in_lock_section(:exclusive) do |exclusive_thread_release_latch|
      sharing_thread = Thread.new { @lock.sharing { } }
      assert_threads_stuck_but_releasable_by_latch sharing_thread, exclusive_thread_release_latch
    end
  end

  def test_multiple_exclusives_are_able_to_progress
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      exclusive_threads = (1..2).map do
        Thread.new do
          @lock.exclusive { }
        end
      end

      assert_threads_stuck_but_releasable_by_latch exclusive_threads, sharing_thread_release_latch
    end
  end

  def test_sharing_is_upgradeable_to_exclusive
    upgrading_thread = Thread.new do
      @lock.sharing do
        @lock.exclusive { }
      end
    end
    assert_threads_not_stuck upgrading_thread
  end

  def test_exclusive_upgrade_waits_for_other_sharers_to_leave
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      in_sharing = Concurrent::CountDownLatch.new

      upgrading_thread = Thread.new do
        @lock.sharing do
          in_sharing.count_down
          @lock.exclusive { }
        end
      end

      in_sharing.wait
      assert_threads_stuck_but_releasable_by_latch upgrading_thread, sharing_thread_release_latch
    end
  end

  def test_exclusive_matching_purpose
    [true, false].each do |use_upgrading|
      with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
        exclusive_threads = (1..2).map do
          Thread.new do
            @lock.public_send(use_upgrading ? :sharing : :tap) do
              @lock.exclusive(purpose: :load, compatible: [:load, :unload]) { }
            end
          end
        end

        assert_threads_stuck_but_releasable_by_latch exclusive_threads, sharing_thread_release_latch
      end
    end
  end

  def test_killed_thread_loses_lock
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      thread = Thread.new do
        @lock.sharing do
          @lock.exclusive { }
        end
      end

      assert_threads_stuck thread
      thread.kill

      sharing_thread_release_latch.count_down

      thread = Thread.new do
        @lock.exclusive { }
      end

      assert_threads_not_stuck thread
    end
  end

  def test_exclusive_conflicting_purpose
    [true, false].each do |use_upgrading|
      with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
        together = Concurrent::CyclicBarrier.new(2)
        conflicting_exclusive_threads = [
          Thread.new do
            @lock.public_send(use_upgrading ? :sharing : :tap) do
              together.wait
              @lock.exclusive(purpose: :red, compatible: [:green, :purple]) { }
            end
          end,
          Thread.new do
            @lock.public_send(use_upgrading ? :sharing : :tap) do
              together.wait
              @lock.exclusive(purpose: :blue, compatible: [:green]) { }
            end
          end
        ]

        assert_threads_stuck conflicting_exclusive_threads # wait for threads to get into their respective `exclusive {}` blocks

        # This thread will be stuck as long as any other thread is in
        # a sharing block. While it's blocked, it holds no lock, so it
        # doesn't interfere with any other attempts.
        no_purpose_thread = Thread.new do
          @lock.exclusive { }
        end
        assert_threads_stuck no_purpose_thread

        # This thread is compatible with both of the "primary"
        # attempts above. It's initially stuck on the outer share
        # lock, but as soon as that's released, it can run --
        # regardless of whether those threads hold share locks.
        compatible_thread = Thread.new do
          @lock.exclusive(purpose: :green, compatible: []) { }
        end
        assert_threads_stuck compatible_thread

        assert_threads_stuck conflicting_exclusive_threads

        sharing_thread_release_latch.count_down

        assert_threads_not_stuck compatible_thread # compatible thread is now able to squeak through

        if use_upgrading
          # The "primary" threads both each hold a share lock, and are
          # mutually incompatible; they're still stuck.
          assert_threads_stuck conflicting_exclusive_threads

          # The thread without a specified purpose is also stuck; it's
          # not compatible with anything.
          assert_threads_stuck no_purpose_thread
        else
          # As the primaries didn't hold a share lock, as soon as the
          # outer one was released, all the exclusive locks are free
          # to be acquired in turn.

          assert_threads_not_stuck conflicting_exclusive_threads
          assert_threads_not_stuck no_purpose_thread
        end
      ensure
        conflicting_exclusive_threads.each(&:kill)
        no_purpose_thread.kill
      end
    end
  end

  def test_exclusive_ordering
    scratch_pad       = []
    scratch_pad_mutex = Mutex.new

    load_params   = [:load,   [:load]]
    unload_params = [:unload, [:unload, :load]]

    all_sharing = Concurrent::CyclicBarrier.new(4)

    [load_params, load_params, unload_params, unload_params].permutation do |thread_params|
      with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
        threads = thread_params.map do |purpose, compatible|
          Thread.new do
            @lock.sharing do
              all_sharing.wait
              @lock.exclusive(purpose: purpose, compatible: compatible) do
                scratch_pad_mutex.synchronize { scratch_pad << purpose }
              end
            end
          end
        end

        sleep(0.01)
        scratch_pad_mutex.synchronize { assert_empty scratch_pad }

        sharing_thread_release_latch.count_down

        assert_threads_not_stuck threads
        scratch_pad_mutex.synchronize do
          assert_equal [:load, :load, :unload, :unload], scratch_pad
          scratch_pad.clear
        end
      end
    end
  end

  def test_new_share_attempts_block_on_waiting_exclusive
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      release_exclusive = Concurrent::CountDownLatch.new

      waiting_exclusive = Thread.new do
        @lock.sharing do
          @lock.exclusive do
            release_exclusive.wait
          end
        end
      end
      assert_threads_stuck waiting_exclusive

      late_share_attempt = Thread.new do
        @lock.sharing { }
      end
      assert_threads_stuck late_share_attempt

      sharing_thread_release_latch.count_down
      assert_threads_stuck late_share_attempt

      release_exclusive.count_down
      assert_threads_not_stuck late_share_attempt
    end
  end

  def test_share_remains_reentrant_ignoring_a_waiting_exclusive
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      ready = Concurrent::CyclicBarrier.new(2)
      attempt_reentrancy = Concurrent::CountDownLatch.new

      sharer = Thread.new do
        @lock.sharing do
          ready.wait
          attempt_reentrancy.wait
          @lock.sharing { }
        end
      end

      exclusive = Thread.new do
        @lock.sharing do
          ready.wait
          @lock.exclusive { }
        end
      end

      assert_threads_stuck exclusive

      attempt_reentrancy.count_down

      assert_threads_not_stuck sharer
      assert_threads_stuck exclusive
    end
  end

  def test_compatible_exclusives_cooperate_to_both_proceed
    ready = Concurrent::CyclicBarrier.new(2)
    done = Concurrent::CyclicBarrier.new(2)

    threads = 2.times.map do
      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.exclusive(purpose: :x, compatible: [:x], after_compatible: [:x]) { }
          done.wait
        end
      end
    end

    assert_threads_not_stuck threads
  end

  def test_manual_yield
    ready = Concurrent::CyclicBarrier.new(2)
    done = Concurrent::CyclicBarrier.new(2)

    threads = [
      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.exclusive(purpose: :x) { }
          done.wait
        end
      end,

      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.yield_shares(compatible: [:x]) do
            done.wait
          end
        end
      end,
    ]

    assert_threads_not_stuck threads
  end

  def test_manual_incompatible_yield
    ready = Concurrent::CyclicBarrier.new(2)
    done = Concurrent::CyclicBarrier.new(2)

    threads = [
      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.exclusive(purpose: :x) { }
          done.wait
        end
      end,

      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.yield_shares(compatible: [:y]) do
            done.wait
          end
        end
      end,
    ]

    assert_threads_stuck threads
  ensure
    threads.each(&:kill) if threads
  end

  def test_manual_recursive_yield
    ready = Concurrent::CyclicBarrier.new(2)
    done = Concurrent::CyclicBarrier.new(2)
    do_nesting = Concurrent::CountDownLatch.new

    threads = [
      Thread.new do
        @lock.sharing do
          ready.wait
          @lock.exclusive(purpose: :x) { }
          done.wait
        end
      end,

      Thread.new do
        @lock.sharing do
          @lock.yield_shares(compatible: [:x]) do
            @lock.sharing do
              ready.wait
              do_nesting.wait
              @lock.yield_shares(compatible: [:x, :y]) do
                done.wait
              end
            end
          end
        end
      end
    ]

    assert_threads_stuck threads
    do_nesting.count_down

    assert_threads_not_stuck threads
  end

  def test_manual_recursive_yield_cannot_expand_outer_compatible
    ready = Concurrent::CyclicBarrier.new(2)
    do_compatible_nesting = Concurrent::CountDownLatch.new
    in_compatible_nesting = Concurrent::CountDownLatch.new

    incompatible_thread = Thread.new do
      @lock.sharing do
        ready.wait
        @lock.exclusive(purpose: :x) { }
      end
    end

    yield_shares_thread = Thread.new do
      @lock.sharing do
        ready.wait
        @lock.yield_shares(compatible: [:y]) do
          do_compatible_nesting.wait
          @lock.sharing do
            @lock.yield_shares(compatible: [:x, :y]) do
              in_compatible_nesting.wait
            end
          end
        end
      end
    end

    assert_threads_stuck incompatible_thread
    do_compatible_nesting.count_down
    assert_threads_stuck incompatible_thread
    in_compatible_nesting.count_down
    assert_threads_not_stuck [yield_shares_thread, incompatible_thread]
  end

  def test_manual_recursive_yield_restores_previous_compatible
    ready = Concurrent::CyclicBarrier.new(2)
    do_nesting = Concurrent::CountDownLatch.new
    after_nesting = Concurrent::CountDownLatch.new

    incompatible_thread = Thread.new do
      ready.wait
      @lock.exclusive(purpose: :z) { }
    end

    recursive_yield_shares_thread = Thread.new do
      @lock.sharing do
        ready.wait
        @lock.yield_shares(compatible: [:y]) do
          do_nesting.wait
          @lock.sharing do
            @lock.yield_shares(compatible: [:x, :y]) { }
          end
          after_nesting.wait
        end
      end
    end

    assert_threads_stuck incompatible_thread
    do_nesting.count_down
    assert_threads_stuck incompatible_thread

    compatible_thread = Thread.new do
      @lock.exclusive(purpose: :y) { }
    end
    assert_threads_not_stuck compatible_thread

    post_nesting_incompatible_thread = Thread.new do
      @lock.exclusive(purpose: :x) { }
    end
    assert_threads_stuck post_nesting_incompatible_thread

    after_nesting.count_down
    assert_threads_not_stuck recursive_yield_shares_thread
    # post_nesting_incompatible_thread can now proceed
    assert_threads_not_stuck post_nesting_incompatible_thread
    # assert_threads_not_stuck can now proceed
    assert_threads_not_stuck incompatible_thread
  end

  def test_in_shared_section_incompatible_non_upgrading_threads_cannot_preempt_upgrading_threads
    scratch_pad       = []
    scratch_pad_mutex = Mutex.new

    upgrading_load_params       = [:load,   [:load],          true]
    non_upgrading_unload_params = [:unload, [:load, :unload], false]

    [upgrading_load_params, non_upgrading_unload_params].permutation do |thread_params|
      with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
        threads = thread_params.map do |purpose, compatible, use_upgrading|
          Thread.new do
            @lock.public_send(use_upgrading ? :sharing : :tap) do
              @lock.exclusive(purpose: purpose, compatible: compatible) do
                scratch_pad_mutex.synchronize { scratch_pad << purpose }
              end
            end
          end
        end

        assert_threads_stuck threads
        scratch_pad_mutex.synchronize { assert_empty scratch_pad }

        sharing_thread_release_latch.count_down

        assert_threads_not_stuck threads
        scratch_pad_mutex.synchronize do
          assert_equal [:load, :unload], scratch_pad
          scratch_pad.clear
        end
      end
    end
  end

  private
    module CustomAssertions
      SUFFICIENT_TIMEOUT = 0.2

      private
        def assert_threads_stuck_but_releasable_by_latch(threads, latch)
          assert_threads_stuck threads
          latch.count_down
          assert_threads_not_stuck threads
        end

        def assert_threads_stuck(threads)
          sleep(SUFFICIENT_TIMEOUT) # give threads time to do their business
          assert(Array(threads).all? { |t| t.join(0.001).nil? })
        end

        def assert_threads_not_stuck(threads)
          assert(Array(threads).all? { |t| t.join(SUFFICIENT_TIMEOUT) })
        end
    end

    class CustomAssertionsTest < ActiveSupport::TestCase
      include CustomAssertions

      def setup
        @latch = Concurrent::CountDownLatch.new
        @thread = Thread.new { @latch.wait }
      end

      def teardown
        @latch.count_down
        @thread.join
      end

      def test_happy_path
        assert_threads_stuck_but_releasable_by_latch @thread, @latch
      end

      def test_detects_stuck_thread
        assert_raises(Minitest::Assertion) do
          assert_threads_not_stuck @thread
        end
      end

      def test_detects_free_thread
        @latch.count_down
        assert_raises(Minitest::Assertion) do
          assert_threads_stuck @thread
        end
      end

      def test_detects_already_released
        @latch.count_down
        assert_raises(Minitest::Assertion) do
          assert_threads_stuck_but_releasable_by_latch @thread, @latch
        end
      end

      def test_detects_remains_latched
        another_latch = Concurrent::CountDownLatch.new
        assert_raises(Minitest::Assertion) do
          assert_threads_stuck_but_releasable_by_latch @thread, another_latch
        end
      end
    end

    include CustomAssertions

    def with_thread_waiting_in_lock_section(lock_section)
      in_section      = Concurrent::CountDownLatch.new
      section_release = Concurrent::CountDownLatch.new

      stuck_thread = Thread.new do
        @lock.send(lock_section) do
          in_section.count_down
          section_release.wait
        end
      end

      in_section.wait

      yield section_release
    ensure
      section_release.count_down
      stuck_thread.join # clean up
    end
end
