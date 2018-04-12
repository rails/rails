# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class CacheEntryTest < ActiveSupport::TestCase
  def test_expired
    entry = ActiveSupport::Cache::Entry.new("value")
    assert !entry.expired?, "entry not expired"
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    assert !entry.expired?, "entry not expired"
    Time.stub(:now, Time.now + 61) do
      assert entry.expired?, "entry is expired"
    end
  end
end
