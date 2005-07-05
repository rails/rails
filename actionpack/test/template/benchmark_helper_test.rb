require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/action_view/helpers/benchmark_helper'

class BenchmarkHelperTest < Test::Unit::TestCase
  include ActionView::Helpers::BenchmarkHelper

  class MockLogger
    attr_reader :logged

    def initialize
      @logged = []
    end

    def method_missing(method, *args)
      @logged << [method, args]
    end
  end

  def setup
    @logger = MockLogger.new
  end

  def test_without_logger_or_block
    @logger = nil
    assert_nothing_raised { benchmark }
  end

  def test_without_block
    assert_raise(LocalJumpError) { benchmark }
    assert @logger.logged.empty?
  end

  def test_without_logger
    @logger = nil
    i_was_run = false
    benchmark { i_was_run = true }
    assert !i_was_run
  end

  def test_defaults
    i_was_run = false
    benchmark { i_was_run = true }
    assert i_was_run
    assert 1, @logger.logged.size
    assert_last_logged
  end

  def test_with_message
    i_was_run = false
    benchmark('test_run') { i_was_run = true }
    assert i_was_run
    assert 1, @logger.logged.size
    assert_last_logged 'test_run'
  end

  def test_with_message_and_level
    i_was_run = false
    benchmark('debug_run', :debug) { i_was_run = true }
    assert i_was_run
    assert 1, @logger.logged.size
    assert_last_logged 'debug_run', :debug
  end

  private
    def assert_last_logged(message = 'Benchmarking', level = :info)
      last = @logger.logged.last
      assert 2, last.size
      assert_equal level, last.first
      assert 1, last[1].size
      assert last[1][0] =~ /^#{message} \(.*\)$/
    end
end
