# frozen_string_literal: true

module FailureRaisingBehavior
  def test_fetch_read_failure_raises
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      cache.fetch("foo")
    end
  end

  def test_fetch_with_block_read_failure_raises
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      cache.fetch("foo") { '1' }
    end
  end

  def test_read_failure_raises
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      cache.read("foo")
    end
  end

  def test_read_multi_failure_raises
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    emulating_unavailability do |cache|
      cache.read_multi("foo", "baz")
    end
  end

  def test_write_failure_raises
    emulating_unavailability do |cache|
      cache.write("foo", "bar")
    end
  end

  def test_write_multi_failure_raises
    emulating_unavailability do |cache|
      cache.write_multi("foo" => "bar", "baz" => "quux")
    end
  end

  def test_fetch_multi_failure_raises
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    emulating_unavailability do |cache|
       cache.fetch_multi("foo", "baz") { |k| "unavailable" }
    end
  end

  def test_delete_failure_raises
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      cache.delete("foo")
    end
  end

  def test_exist_failure_raises
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      cache.exist?("foo")
    end
  end

  def test_increment_failure_raises
    @cache.write("foo", 1, raw: true)

    emulating_unavailability do |cache|
      cache.increment("foo")
    end
  end

  def test_decrement_failure_raises
    @cache.write("foo", 1, raw: true)

    emulating_unavailability do |cache|
      cache.decrement("foo")
    end
  end

  def test_clear_failure_returns_nil
    emulating_unavailability do |cache|
      assert_nil cache.clear
    end
  end
end
