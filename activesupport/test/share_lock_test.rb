require 'abstract_unit'
require 'concurrent/atomics'
require 'active_support/concurrency/share_lock'

class ShareLockTest < ActiveSupport::TestCase
  def setup
    @lock = ActiveSupport::Concurrency::ShareLock.new
  end

  def test_sharing_doesnt_block
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_latch|
      assert_threads_not_stuck(Thread.new {@lock.sharing {} })
    end
  end

  def test_sharing_blocks_exclusive
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      @lock.exclusive(no_wait: true) { flunk } # polling should fail
      exclusive_thread = Thread.new { @lock.exclusive {} }
      assert_threads_stuck_but_releasable_by_latch exclusive_thread, sharing_thread_release_latch
    end
  end

  def test_exclusive_blocks_sharing
    with_thread_waiting_in_lock_section(:exclusive) do |exclusive_thread_release_latch|
      sharing_thread = Thread.new { @lock.sharing {} }
      assert_threads_stuck_but_releasable_by_latch sharing_thread, exclusive_thread_release_latch
    end
  end

  def test_multiple_exlusives_are_able_to_progress
    with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
      exclusive_threads = (1..2).map do
        Thread.new do
          @lock.exclusive {}
        end
      end

      assert_threads_stuck_but_releasable_by_latch exclusive_threads, sharing_thread_release_latch
    end
  end

  def test_sharing_is_upgradeable_to_exclusive
    upgrading_thread = Thread.new do
      @lock.sharing do
        @lock.exclusive {}
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
          @lock.exclusive {}
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
            @lock.send(use_upgrading ? :sharing : :tap) do
              @lock.exclusive(purpose: :load, compatible: [:load, :unload]) {}
            end
          end
        end

        assert_threads_stuck_but_releasable_by_latch exclusive_threads, sharing_thread_release_latch
      end
    end
  end

  def test_exclusive_conflicting_purpose
    [true, false].each do |use_upgrading|
      with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
        begin
          conflicting_exclusive_threads = [
            Thread.new do
              @lock.send(use_upgrading ? :sharing : :tap) do
                @lock.exclusive(purpose: :load, compatible: [:load]) {}
              end
            end,
            Thread.new do
              @lock.send(use_upgrading ? :sharing : :tap) do
                @lock.exclusive(purpose: :unload, compatible: [:unload]) {}
              end
            end
          ]

          assert_threads_stuck conflicting_exclusive_threads # wait for threads to get into their respective `exclusive {}` blocks
          sharing_thread_release_latch.count_down
          assert_threads_stuck conflicting_exclusive_threads # assert they are stuck

          no_purpose_thread = Thread.new do
            @lock.exclusive {}
          end
          assert_threads_not_stuck no_purpose_thread # no purpose thread is able to squeak through

          compatible_thread = Thread.new do
            @lock.exclusive(purpose: :load, compatible: [:load, :unload])
          end

          assert_threads_not_stuck compatible_thread # compatible thread is able to squeak through
          assert_threads_stuck conflicting_exclusive_threads # assert other threads are still stuck
        ensure
          conflicting_exclusive_threads.each(&:kill)
        end
      end
    end
  end

  def test_exclusive_ordering
    [true, false].each do |use_upgrading|
      scratch_pad       = []
      scratch_pad_mutex = Mutex.new

      load_params   = [:load,   [:load]]
      unload_params = [:unload, [:unload, :load]]

      [load_params, load_params, unload_params, unload_params].permutation do |thread_params|
        with_thread_waiting_in_lock_section(:sharing) do |sharing_thread_release_latch|
          threads = thread_params.map do |purpose, compatible|
            Thread.new do
              @lock.send(use_upgrading ? :sharing : :tap) do
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
  end

  private
  SUFFICIENT_TIMEOUT = 0.2

  def assert_threads_stuck_but_releasable_by_latch(threads, latch)
    assert_threads_stuck threads
    latch.count_down
    assert_threads_not_stuck threads
  end

  def assert_threads_stuck(threads)
    sleep(SUFFICIENT_TIMEOUT) # give threads time to do their business
    assert(Array(threads).all? {|t| t.join(0.001).nil?})
  end

  def assert_threads_not_stuck(threads)
    assert_not_nil(Array(threads).all? {|t| t.join(SUFFICIENT_TIMEOUT)})
  end

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
