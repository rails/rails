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
      assert_predicate entry, :expired?, "entry is expired"
    end
  end

  def test_initialize_with_expires_at
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    clone = ActiveSupport::Cache::Entry.new("value", expires_at: entry.expires_at)
    assert_equal entry.expires_at, clone.expires_at
  end

  def test_should_expire_early?
    options = { current_time: 0.0, expired_at: 10.0, generation_time: 1.0 }
    assert_early_expiration(true, random: 0, **options)
    assert_early_expiration(true, random: Math::E**-10, **options)
    assert_early_expiration(false, random: Math::E**-10 + 1e-4, **options)
  end

  private
    def assert_early_expiration(expected, current_time:, expired_at:, generation_time:, random:)
      entry = ActiveSupport::Cache::Entry.new(
        "value", generation_time: generation_time, expires_at: expired_at
      )
      Time.stub(:now, current_time) do
        Kernel.stub(:rand, random) do
          assert_equal expected, entry.should_expire_early?
        end
      end
    end
end
