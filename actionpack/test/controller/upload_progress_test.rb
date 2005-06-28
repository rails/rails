require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'
require 'cgi'
require 'stringio'

class UploadProgressTest < Test::Unit::TestCase
  def test_remaining
    progress = new_progress(20000)
    assert_equal(0, progress.received_bytes)
    assert_equal(20000, progress.remaining_bytes)
    progress.update!(10000, 1.0)
    assert_equal(10000, progress.remaining_bytes)
    assert_equal(1.0, progress.remaining_seconds)
    assert_equal(50, progress.completed_percent)
    assert_equal(true, progress.started?)
    assert_equal(false, progress.finished?)
    assert_equal(false, progress.stalled?)
    progress.update!(10000, 2.0)
    assert_equal(true, progress.finished?)
    assert_equal(0.0, progress.remaining_seconds)
  end

  def test_stalled
    progress = new_progress(10000)
    assert_equal(false, progress.stalled?)
    progress.update!(100, 1.0)
    assert_equal(false, progress.stalled?)
    progress.update!(100, 20.0)
    assert_equal(true, progress.stalled?)
    assert_in_delta(0.0, progress.bitrate, 0.001)
    progress.update!(100, 21.0)
    assert_equal(false, progress.stalled?)
  end

  def test_elapsed
    progress = new_progress(10000)
    (1..5).each do |t|
      progress.update!(1000, Float(t))
    end
    assert_in_delta(5.0, progress.elapsed_seconds, 0.001)
    assert_equal(10000, progress.total_bytes)
    assert_equal(5000, progress.received_bytes)
    assert_equal(5000, progress.remaining_bytes)
  end

  def test_overflow
    progress = new_progress(10000)
    progress.update!(20000, 1.0)
    assert_equal(10000, progress.received_bytes)
  end

  def test_zero
    progress = new_progress(0)
    assert_equal(0, progress.total_bytes)
    assert_equal(0, progress.remaining_bytes)
    assert_equal(false, progress.started?)
    assert_equal(true, progress.finished?)
    assert_equal(0, progress.bitrate)
    assert_equal(0, progress.completed_percent)
    assert_equal(0, progress.remaining_seconds)
  end

  def test_finished
    progress = new_progress(10000)
    (1..9).each do |t|
      progress.update!(1000, Float(t))
      assert_equal(false, progress.finished?)
      assert_equal(1000.0, progress.bitrate)
      assert_equal(false, progress.stalled?)
    end
    assert_equal(false, progress.finished?)
    progress.update!(1000, 10.0)
    assert_equal(true, progress.finished?)
  end

  def test_rapid_samples
    progress = new_progress(10000)
    (1..1000).each do |t|
      progress.update!(10, t/100.0)
    end
    assert_in_delta(1000.0, progress.bitrate, 0.001)
    assert_equal(true, progress.finished?)
  end

  private
    def new_progress(total)
      ActionController::UploadProgress::Progress.new(total)
    end
end
