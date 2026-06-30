# frozen_string_literal: true

require_relative "abstract_unit"

module ActiveSupport
  class ProxyLoggerTest < TestCase
    setup do
      @io = StringIO.new
      @real_logger = Logger.new(@io)
      @logger = ProxyLogger.new(@real_logger)
    end

    def test_own_level_interface
      @real_logger.debug("REAL-1")
      @logger.debug("PROXY-1")

      @logger.level = :error

      @real_logger.debug("REAL-2")
      @logger.debug("PROXY-2")

      assert_equal %w(REAL-1 PROXY-1 REAL-2), @io.string.split("\n")
    end

    def test_underlying_level_interface
      @real_logger.debug("REAL-1")
      @logger.debug("PROXY-1")

      @real_logger.level = :error

      @real_logger.debug("REAL-2")
      @logger.debug("PROXY-2")

      assert_equal %w(REAL-1 PROXY-1), @io.string.split("\n")
    end

    def test_silence
      @logger.silence do
        @logger.info("SILENCED")
        @logger.error("PASSES")
      end
      @logger.info("AFTER")

      assert_equal %w(PASSES AFTER), @io.string.split("\n")
    end

    def test_silence_only_affects_the_receiver
      other = ProxyLogger.new(@real_logger)
      @logger.silence do
        other.info("OTHER")
      end

      assert_equal %w(OTHER), @io.string.split("\n")
    end

    def test_close_and_reopen
      @logger.debug("BEFORE")
      @logger.close
      @logger.debug("CLOSED")
      @logger.reopen(@real_logger)
      @logger.debug("AFTER")

      assert_equal %w(BEFORE AFTER), @io.string.split("\n")
    end

    def test_all_delegators
      @logger.debug("DEBUG")
      @logger.info("INFO")
      @logger.warn("WARN")
      @logger.error("ERROR")
      @logger.fatal("FATAL")
      @logger.unknown("UNKNOWN")
      assert_equal %w(DEBUG INFO WARN ERROR FATAL UNKNOWN), @io.string.split("\n")
    end

    def test_all_block_delegators
      @logger.debug { "DEBUG" }
      @logger.info { "INFO" }
      @logger.warn { "WARN" }
      @logger.error { "ERROR" }
      @logger.fatal { "FATAL" }
      @logger.unknown { "UNKNOWN" }
      assert_equal %w(DEBUG INFO WARN ERROR FATAL UNKNOWN), @io.string.split("\n")
    end
  end
end
