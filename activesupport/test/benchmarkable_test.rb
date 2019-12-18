# frozen_string_literal: true

require_relative "abstract_unit"

class BenchmarkableTest < ActiveSupport::TestCase
  include ActiveSupport::Benchmarkable

  attr_reader :buffer, :logger

  class Buffer
    include Enumerable

    def initialize; @lines = []; end
    def each(&block); @lines.each(&block); end
    def write(x); @lines << x; end
    def close; end
    def last; @lines.last; end
    def size; @lines.size; end
    def empty?; @lines.empty?; end
  end

  def setup
    @buffer = Buffer.new
    @logger = ActiveSupport::Logger.new(@buffer)
  end

  def test_without_block
    assert_raise(LocalJumpError) { benchmark }
    assert_empty buffer
  end

  def test_defaults
    i_was_run = false
    benchmark { i_was_run = true }
    assert i_was_run
    assert_last_logged
  end

  def test_with_message
    i_was_run = false
    benchmark("test_run") { i_was_run = true }
    assert i_was_run
    assert_last_logged "test_run"
  end

  def test_with_silence
    assert_difference "buffer.count", +2 do
      benchmark("test_run") do
        logger.info "SOMETHING"
      end
    end

    assert_difference "buffer.count", +1 do
      benchmark("test_run", silence: true) do
        logger.info "NOTHING"
      end
    end
  end

  def test_within_level
    logger.level = ActiveSupport::Logger::DEBUG
    benchmark("included_debug_run", level: :debug) { }
    assert_last_logged "included_debug_run"
  end

  def test_outside_level
    logger.level = ActiveSupport::Logger::ERROR
    benchmark("skipped_debug_run", level: :debug) { }
    assert_no_match(/skipped_debug_run/, buffer.last)
  ensure
    logger.level = ActiveSupport::Logger::DEBUG
  end

  private
    def assert_last_logged(message = "Benchmarking")
      assert_match(/^#{message} \(.*\)$/, buffer.last)
    end
end
