# frozen_string_literal: true

require "test_helper"
require "active_support/broadcast_logger"
require "active_support/tagged_logging"

class TaggedLoggerProxyTest < ActionCable::TestCase
  test "tag logs when the logger's formatter does not keep tags" do
    io = StringIO.new
    logger = ActiveSupport::BroadcastLogger.new(Logger.new(io))
    proxy = ActionCable::Server::TaggedLoggerProxy.new(logger, tags: ["ActionCable"])

    assert_equal :tagged, proxy.tag(logger) { logger.info("hello"); :tagged }
    assert_includes io.string, "hello"
  end

  test "tag does not repeat tags the formatter already carries" do
    io = StringIO.new
    logger = ActiveSupport::TaggedLogging.new(Logger.new(io))
    proxy = ActionCable::Server::TaggedLoggerProxy.new(logger, tags: ["ActionCable"])

    logger.tagged("ActionCable") do
      proxy.tag(logger) { logger.info "hello" }
    end

    assert_equal 1, io.string.scan("[ActionCable]").size
  end
end
