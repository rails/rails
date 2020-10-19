# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"

class CacheCoderTest < ActiveSupport::TestCase
  def test_new_coder_can_read_legacy_payloads
    entry = ActiveSupport::Cache::Entry.new("foobar", expires_in: 1.hour, version: "v42")
    deserialized_entry = ActiveSupport::Cache::Coders::Rails70Coder.load(
      ActiveSupport::Cache::Coders::Rails61Coder.dump(entry),
    )

    assert_equal entry.value, deserialized_entry.value
    assert_equal entry.version, deserialized_entry.version
    assert_equal entry.expires_at, deserialized_entry.expires_at
  end

  def test_legacy_coder_can_read_new_payloads
    entry = ActiveSupport::Cache::Entry.new("foobar", expires_in: 1.hour, version: "v42")
    deserialized_entry = ActiveSupport::Cache::Coders::Rails61Coder.load(
      ActiveSupport::Cache::Coders::Rails70Coder.dump(entry),
    )

    assert_equal entry.value, deserialized_entry.value
    assert_equal entry.version, deserialized_entry.version
    assert_equal entry.expires_at, deserialized_entry.expires_at
  end
end
