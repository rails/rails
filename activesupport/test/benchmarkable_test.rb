require 'abstract_unit'

class BenchmarkableTest < ActiveSupport::TestCase
  include ActiveSupport::Benchmarkable

  def teardown
    logger.send(:clear_buffer)
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
    logger.level = ActiveSupport::BufferedLogger::DEBUG
    benchmark('included_debug_run', :level => :debug) { }
    assert_last_logged 'included_debug_run'
  end

  def test_outside_level
    logger.level = ActiveSupport::BufferedLogger::ERROR
    benchmark('skipped_debug_run', :level => :debug) { }
    assert_no_match(/skipped_debug_run/, buffer.last)
  ensure
    logger.level = ActiveSupport::BufferedLogger::DEBUG
  end

  def test_without_silencing
    benchmark('debug_run', :silence => false) do
      logger.info "not silenced!"
    end

    assert_equal 2, buffer.size
  end

  def test_with_silencing
    benchmark('debug_run', :silence => true) do
      logger.info "silenced!"
    end

    assert_equal 1, buffer.size
  end

  private
    def logger
      @logger ||= begin
        logger = ActiveSupport::BufferedLogger.new(StringIO.new)
        logger.auto_flushing = false
        logger
      end
    end

    def buffer
      logger.send(:buffer)
    end

    def assert_last_logged(message = 'Benchmarking')
      assert_match(/^#{message} \(.*\)$/, buffer.last)
    end
end
