# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class CacheStoreLoggerTest < ActiveSupport::TestCase
  def setup
    @cache = ActiveSupport::Cache.lookup_store(:memory_store)

    @buffer = StringIO.new
    @cache.logger = ActiveSupport::Logger.new(@buffer)
  end

  def test_logging
    @cache.fetch("foo") { "bar" }
    assert_predicate @buffer.string, :present?
  end

  def test_log_with_string_namespace
    @cache.fetch("foo", namespace: "string_namespace") { "bar" }
    assert_match %r{string_namespace:foo}, @buffer.string
  end

  def test_log_with_proc_namespace
    proc = Proc.new do
      "proc_namespace"
    end
    @cache.fetch("foo", namespace: proc) { "bar" }
    assert_match %r{proc_namespace:foo}, @buffer.string
  end

  def test_mute_logging
    @cache.mute { @cache.fetch("foo") { "bar" } }
    assert_predicate @buffer.string, :blank?
  end
end
