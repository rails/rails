require 'abstract_unit'
require 'action_view/helpers/benchmark_helper'

class BenchmarkHelperTest < ActionView::TestCase
  tests ActionView::Helpers::BenchmarkHelper

  def setup
    super
    controller.logger = ActiveSupport::BufferedLogger.new(StringIO.new)
    controller.logger.auto_flushing = false
  end

  def teardown
    controller.logger.send(:clear_buffer)
  end

  def test_without_block
    assert_raise(LocalJumpError) { benchmark }
    assert buffer.empty?
  end

  def test_defaults
    i_was_run = false
    benchmark { i_was_run = true }
    assert i_was_run
    assert_last_logged
  end

  def test_with_message
    i_was_run = false
    benchmark('test_run') { i_was_run = true }
    assert i_was_run
    assert_last_logged 'test_run'
  end

  def test_with_message_and_deprecated_level
    i_was_run = false

    assert_deprecated do
      benchmark('debug_run', :debug) { i_was_run = true }
    end

    assert i_was_run
    assert_last_logged 'debug_run'
  end

  def test_within_level
    controller.logger.level = ActiveSupport::BufferedLogger::DEBUG
    benchmark('included_debug_run', :level => :debug) { }
    assert_last_logged 'included_debug_run'
  end

  def test_outside_level
    controller.logger.level = ActiveSupport::BufferedLogger::ERROR
    benchmark('skipped_debug_run', :level => :debug) { }
    assert_no_match(/skipped_debug_run/, buffer.last)
  ensure
    controller.logger.level = ActiveSupport::BufferedLogger::DEBUG
  end

  def test_without_silencing
    benchmark('debug_run', :silence => false) do
      controller.logger.info "not silenced!"
    end

    assert_equal 2, buffer.size
  end

  def test_with_silencing
    benchmark('debug_run', :silence => true) do
      controller.logger.info "silenced!"
    end

    assert_equal 1, buffer.size
  end


  private
    def buffer
      controller.logger.send(:buffer)
    end
  
    def assert_last_logged(message = 'Benchmarking')
      assert_match(/^#{message} \(.*\)$/, buffer.last)
    end
end
