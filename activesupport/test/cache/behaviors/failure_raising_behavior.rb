# frozen_string_literal: true

module FailureRaisingBehavior
  def test_fetch_read_failure_raises
    @cache.write("foo", "bar")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch("foo")
      end
    end
  end

  def test_fetch_with_block_read_failure_raises
    @cache.write("foo", "bar")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch("foo") { "1" }
      end
    end

    assert_equal "bar", @cache.read("foo")
  end

  def test_read_failure_raises
    @cache.write("foo", "bar")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.read("foo")
      end
    end
  end

  def test_read_multi_failure_raises
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.read_multi("foo", "baz")
      end
    end
  end

  def test_write_failure_raises
    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.write("foo", "bar")
      end
    end
  end

  def test_write_multi_failure_raises
    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.write_multi("foo" => "bar", "baz" => "quux")
      end
    end
  end

  def test_fetch_multi_failure_raises
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.fetch_multi("foo", "baz") { |k| "unavailable" }
      end
    end
  end

  def test_delete_failure_raises
    @cache.write("foo", "bar")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.delete("foo")
      end
    end
  end

  def test_exist_failure_raises
    @cache.write("foo", "bar")

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.exist?("foo")
      end
    end
  end

  def test_increment_failure_raises
    @cache.write("foo", 1, raw: true)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.increment("foo")
      end
    end
  end

  def test_decrement_failure_raises
    @cache.write("foo", 1, raw: true)

    assert_raise Redis::BaseError do
      emulating_unavailability do |cache|
        cache.decrement("foo")
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
