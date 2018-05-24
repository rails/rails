# frozen_string_literal: true

require "active_support/testing/autorun"
require "active_support/cache"

# Ensures active_support/cache is loadable on its own without active_support.
class CacheLoadTest < ::Minitest::Test
  def test_load
    assert_nil ActiveSupport::Cache::MemoryStore.new.read(nil)
  end
end
