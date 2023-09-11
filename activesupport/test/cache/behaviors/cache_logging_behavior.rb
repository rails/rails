# frozen_string_literal: true

require "active_support/core_ext/object/with"

module CacheLoggingBehavior
  def test_read_multi_logging
    assert_logs("Cache read_multi: 1 key(s)") { @cache.read_multi("foo") }
    assert_logs("Cache read_multi: 2 key(s)") { @cache.read_multi("foo", "bar") }
  end

  def test_write_multi_logging
    key = SecureRandom.uuid
    assert_logs("Cache write_multi: 1 key(s)") { @cache.write_multi("#{key}1" => 1) }
    assert_logs("Cache write_multi: 2 key(s)") { @cache.write_multi("#{key}1" => 1, "#{key}2" => 2) }
  end

  def test_delete_multi_logging
    key = SecureRandom.uuid
    assert_logs("Cache delete_multi: 1 key(s)") { @cache.delete_multi(["#{key}1"]) }
    assert_logs("Cache delete_multi: 2 key(s)") { @cache.delete_multi(["#{key}1", "#{key}2"]) }
  end

  private
    def assert_logs(pattern, &block)
      io = StringIO.new
      ActiveSupport::Cache::Store.with(logger: Logger.new(io, level: :debug), &block)
      assert_match pattern, io.string
    end
end
