# frozen_string_literal: true

module FailureSafetyBehavior
  def test_fetch_read_failure_returns_nil
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    emulating_unavailability do |cache|
      assert_nil cache.fetch(key)
    end
  end

  def test_fetch_read_failure_does_not_attempt_to_write
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.write(key, value)

    emulating_unavailability do |cache|
      val = cache.fetch(key) { "1" }

      ##
      # Though the `write` part of fetch fails for the same reason
      # `read` will, the block result is still executed and returned.
      assert_equal "1", val
    end

    assert_equal value, @cache.read(key)
  end

  def test_read_failure_returns_nil
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    emulating_unavailability do |cache|
      assert_nil cache.read(key)
    end
  end

  def test_read_multi_failure_returns_empty_hash
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write_multi(
      key => SecureRandom.alphanumeric,
      other_key => SecureRandom.alphanumeric
    )

    emulating_unavailability do |cache|
      assert_equal Hash.new, cache.read_multi(key, other_key)
    end
  end

  def test_write_failure_returns_false
    key = SecureRandom.uuid
    emulating_unavailability do |cache|
      assert_equal false, cache.write(key, SecureRandom.alphanumeric)
    end
  end

  def test_write_multi_failure_not_raises
    emulating_unavailability do |cache|
      assert_nothing_raised do
        cache.write_multi(
          SecureRandom.uuid => SecureRandom.alphanumeric,
          SecureRandom.uuid => SecureRandom.alphanumeric
        )
      end
    end
  end

  def test_fetch_multi_failure_returns_fallback_results
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write_multi(
      key => SecureRandom.alphanumeric,
      other_key => SecureRandom.alphanumeric
    )


    emulating_unavailability do |cache|
      fetched = cache.fetch_multi(key, other_key) { |k| "unavailable" }
      assert_equal Hash[key => "unavailable", other_key => "unavailable"], fetched
    end
  end

  def test_delete_failure_returns_false
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    emulating_unavailability do |cache|
      assert_equal false, cache.delete(key)
    end
  end

  def test_exist_failure_returns_false
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    emulating_unavailability do |cache|
      assert_not cache.exist?(key)
    end
  end

  def test_increment_failure_returns_nil
    key = SecureRandom.uuid
    @cache.write(key, 1, raw: true)

    emulating_unavailability do |cache|
      assert_nil cache.increment(key)
    end
  end

  def test_decrement_failure_returns_nil
    key = SecureRandom.uuid
    @cache.write(key, 1, raw: true)

    emulating_unavailability do |cache|
      assert_nil cache.decrement(key)
    end
  end

  def test_clear_failure_returns_nil
    emulating_unavailability do |cache|
      assert_nil cache.clear
    end
  end
end
