# frozen_string_literal: true

require_relative "abstract_unit"
require "fileutils"
require "timeout"

class RactorLoggerTest < ActiveSupport::TestCase
  if RUBY_VERSION >= "4.0"
    include ActiveSupport::Testing::Isolation

    test ".ractor_logger writes through a writer" do
      path = log_path("basic.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      logger.info("hello")
      logger.flush

      assert_includes File.read(path), "hello"
    ensure
      logger&.close
    end

    test ".ractor_logger returns a ::Logger subclass wrapped with tagged logging" do
      path = log_path("subclass.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      assert_kind_of ActiveSupport::Ractors::Logger, logger
      assert_kind_of ::Logger, logger
    ensure
      logger&.close
    end

    test "consumer preserves Logger::LogDevice rotation" do
      path = log_path("rotation.log")
      # Rotate after a tiny size so a few writes trigger a roll-over.
      logger = ActiveSupport::Ractors::Logger.new(path, 5, 64)

      20.times { |i| logger.info("rotation-message-#{i}") }
      logger.flush

      assert_not_empty Dir["#{path}.*"], "expected Logger::LogDevice to rotate the log file"
    ensure
      logger&.close
    end

    test "reopen refreshes the device after the file is rotated externally" do
      path = log_path("reopen.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      logger.info("before")
      logger.flush

      rotated = "#{path}.1"
      File.rename(path, rotated) # an external tool moves the file, like logrotate

      logger.reopen # reopen the same path -> a fresh file
      logger.info("after")
      logger.flush

      assert_includes File.read(rotated), "before"
      assert_includes File.read(path), "after"
      assert_not_includes File.read(path), "before"
    ensure
      logger&.close
    end

    test "uses Active Support tagged logging formatter for tags" do
      path = log_path("tags.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      logger.tagged("request-id") { logger.info("hello") }
      logger.flush

      assert_includes File.read(path), "[request-id] hello"
    ensure
      logger&.close
    end

    test "uses LocalTagStorage for tagged logger without block" do
      path = log_path("local_tag_storage.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      tagged_logger = logger.tagged("job")
      tagged_logger.info("performed")
      logger.info("plain")
      logger.flush

      contents = File.read(path)
      assert_includes contents, "[job] performed"
      assert_includes contents, "plain"
      assert_not_includes contents, "[job] plain"
    ensure
      logger&.close
    end

    test "log_at uses logger-local level storage" do
      path = log_path("log_at.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)
      logger.level = Logger::INFO

      logger.debug("outside")
      logger.log_at(:debug) { logger.debug("inside") }
      logger.debug("outside-again")
      logger.flush

      contents = File.read(path)
      assert_includes contents, "inside"
      assert_not_includes contents, "outside"
      assert_not_includes contents, "outside-again"
    ensure
      logger&.close
    end

    test "log_at works through BroadcastLogger" do
      path = log_path("broadcast_log_at.log")
      ractor_logger = ActiveSupport::TaggedLogging.ractor_logger(path)
      logger = ActiveSupport::BroadcastLogger.new(ractor_logger)
      logger.level = Logger::INFO

      logger.debug("outside")
      logger.log_at(:debug) { logger.debug("inside") }
      logger.debug("outside-again")
      ractor_logger.flush

      contents = File.read(path)
      assert_includes contents, "inside"
      assert_not_includes contents, "outside"
      assert_not_includes contents, "outside-again"
    ensure
      ractor_logger&.close
    end

    test "silence uses logger-local level storage" do
      path = log_path("silence.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)
      logger.level = Logger::DEBUG

      logger.silence(Logger::ERROR) { logger.info("quiet-line") }
      logger.info("loud-line")
      logger.flush

      contents = File.read(path)
      assert_includes contents, "loud-line"
      assert_not_includes contents, "quiet-line"
    ensure
      logger&.close
    end

    test "shareable logger writer is shareable" do
      path = log_path("shareable_writer.log")
      writer = ActiveSupport::Ractors::Logger::Writer.spawn(path)

      assert Ractor.shareable?(writer)

      writer.async("hello\n")
      writer.flush

      assert_includes File.read(path), "hello"
    ensure
      writer&.shutdown
    end

    test "shareable logger can be made shareable" do
      path = log_path("shareable.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)

      Ractor.make_shareable(logger)

      assert Ractor.shareable?(logger)
      logger.tagged("shareable") { logger.info("hello") }
      logger.flush

      assert_includes File.read(path), "[shareable] hello"
    ensure
      logger&.close
    end

    test "a shareable logger logs from a non-main Ractor" do
      path = log_path("from_ractor.log")
      logger = ActiveSupport::TaggedLogging.ractor_logger(path)
      Ractor.make_shareable(logger)

      Ractor.new(logger) do |lg|
        lg.tagged("request-id") { lg.info("from ractor") }
        :done
      end.value

      logger.flush

      assert_includes File.read(path), "[request-id] from ractor"
    ensure
      logger&.close
    end

    test "a failing log device does not kill the consumer or raise in the caller" do
      device = FailingDevice.new(fail_writes: true, fail_flush: true)
      logger = ActiveSupport::TaggedLogging.ractor_logger(device)

      capture_io do
        Timeout.timeout(5) do
          assert_equal true, logger.info("swallowed")  # write error swallowed
          assert_equal true, logger.flush              # flush error swallowed, no hang/raise

          device.recover!
          logger.info("after recovery")
          logger.flush
        end
      end

      assert_includes device.written.join, "after recovery"
    ensure
      logger&.close
    end

    test "a dead consumer degrades to a no-op instead of hanging" do
      null_device = ActiveSupport::Ractors::Logger::Writer::NullDevice.new
      writer = ActiveSupport::Ractors::Logger::Writer.spawn(null_device)
      writer.instance_variable_get(:@port).close # simulate a consumer that has gone away

      Timeout.timeout(5) do
        assert_nil writer.async("dropped\n")
        assert_nil writer.flush
      end
    end
  end

  class FailingDevice
    attr_reader :written

    def initialize(fail_writes:, fail_flush:)
      @fail_writes = fail_writes
      @fail_flush = fail_flush
      @written = []
    end

    def recover!
      @fail_writes = false
      @fail_flush = false
    end

    def write(message)
      raise IOError, "write boom" if @fail_writes
      @written << message
    end

    def flush
      raise IOError, "flush boom" if @fail_flush
    end

    def close; end
  end

  private
    def log_path(name)
      tmp_dir = File.join(__dir__, "tmp", "ractor_logger_test")
      FileUtils.mkdir_p(tmp_dir)
      path = File.join(tmp_dir, name)
      File.delete(path) if File.exist?(path)
      path
    end
end
