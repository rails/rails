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
      @logger.log(::Logger::DEBUG, "LOG")
      @logger.debug("DEBUG")
      @logger.info("INFO")
      @logger.warn("WARN")
      @logger.error("ERROR")
      @logger.fatal("FATAL")
      @logger.unknown("UNKNOWN")
      assert_equal %w(LOG DEBUG INFO WARN ERROR FATAL UNKNOWN), @io.string.split("\n")
    end

    def test_ignore
      assert_same @logger, @logger.ignore(/IGNORED/)
      @logger.ignore(/DROPPED/, "SKIPPED")

      @logger.error("IGNORED-1")
      @logger.add(::Logger::ERROR, "DROPPED-2")
      @logger.error("SKIPPED")
      @logger.error("PASSES")

      assert_equal %w(PASSES), @io.string.split("\n")
    end

    def test_ignore_only_affects_the_receiver
      other = ProxyLogger.new(@real_logger)
      @logger.ignore(/IGNORED/)

      other.error("IGNORED")

      assert_equal %w(IGNORED), @io.string.split("\n")
    end

    def test_ignore_forwards_messages_with_an_invalid_encoding
      @logger.ignore(/IGNORED/)

      @logger.error("PASSES \xE9".dup.force_encoding(Encoding::UTF_8))

      assert_includes @io.string.b, "PASSES"
    end

    def test_ignore_matches_non_string_messages
      @logger.ignore(/IGNORED/)

      @logger.error([:IGNORED, 1])
      @logger.error([:PASSES, 1])

      assert_equal ["[:PASSES, 1]"], @io.string.split("\n")
    end

    def test_ignore_preserves_progname
      @real_logger.formatter = ->(severity, _time, progname, msg) { "#{severity}|#{progname}|#{msg}\n" }
      @logger.ignore(/IGNORED/)

      @logger.error("PASSES-1")
      @logger.add(::Logger::ERROR, "PASSES-2", "PROG")

      assert_equal ["ERROR||PASSES-1", "ERROR|PROG|PASSES-2"], @io.string.split("\n")
    end

    def test_all_block_delegators
      @logger.log(::Logger::DEBUG) { "LOG" }
      @logger.debug { "DEBUG" }
      @logger.info { "INFO" }
      @logger.warn { "WARN" }
      @logger.error { "ERROR" }
      @logger.fatal { "FATAL" }
      @logger.unknown { "UNKNOWN" }
      assert_equal %w(LOG DEBUG INFO WARN ERROR FATAL UNKNOWN), @io.string.split("\n")
    end
  end
end
