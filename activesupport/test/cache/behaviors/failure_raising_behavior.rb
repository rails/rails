# frozen_string_literal: true

module FailureRaisingBehavior
  def test_fetch_read_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch(key)
      end
    end
  end

  def test_fetch_with_block_read_failure_raises
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric
    @cache.write(key, value)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch(key) { SecureRandom.alphanumeric }
      end
    end

    assert_equal value, @cache.read(key)
  end

  def test_read_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.read(key)
      end
    end
  end

  def test_read_multi_failure_raises
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write_multi(
      key => SecureRandom.alphanumeric,
      other_key => SecureRandom.alphanumeric
    )

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.read_multi(key, other_key)
      end
    end
  end

  def test_write_failure_raises
    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.write(SecureRandom.uuid, SecureRandom.alphanumeric)
      end
    end
  end

  def test_write_multi_failure_raises
    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.write_multi(
          SecureRandom.uuid => SecureRandom.alphanumeric,
          SecureRandom.uuid => SecureRandom.alphanumeric
        )
      end
    end
  end

  def test_fetch_multi_failure_raises
    key = SecureRandom.uuid
    other_key = SecureRandom.uuid
    @cache.write_multi(
      key => SecureRandom.alphanumeric,
      other_key => SecureRandom.alphanumeric
    )

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch_multi(key, other_key) { |k| "unavailable" }
      end
    end
  end

  def test_delete_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.delete(key)
      end
    end
  end

  def test_exist_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, SecureRandom.alphanumeric)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.exist?(key)
      end
    end
  end

  def test_increment_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, 1, raw: true)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.increment(key)
      end
    end
  end

  def test_decrement_failure_raises
    key = SecureRandom.uuid
    @cache.write(key, 1, raw: true)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.decrement(key)
      end
    end
  end

  def test_clear_failure_returns_nil
    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.clear
      end
    end
  end
end
