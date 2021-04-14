# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"

class CacheEntryTest < ActiveSupport::TestCase
  def test_expired
    entry = ActiveSupport::Cache::Entry.new("value")
    assert_not entry.expired?, "entry not expired"
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    assert_not entry.expired?, "entry not expired"
    Time.stub(:now, Time.at(entry.expires_at + 1)) do
      assert entry.expired?, "entry is expired"
    end
  end

  def test_initialize_with_expires_at
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    clone = ActiveSupport::Cache::Entry.new("value", expires_at: entry.expires_at)
    assert_equal entry.expires_at, clone.expires_at
  end
end
