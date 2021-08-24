# frozen_string_literal: true

module FailureSafetyBehavior
  def test_fetch_read_failure_returns_nil
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      assert_nil cache.fetch("foo")
    end
  end

  def test_fetch_read_failure_does_not_attempt_to_write
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      val = cache.fetch("foo") { "1" }

      ##
      # Though the `write` part of fetch fails for the same reason
      # `read` will, the block result is still executed and returned.
      assert_equal "1", val
    end

    assert_equal "bar", @cache.read("foo")
  end

  def test_read_failure_returns_nil
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      assert_nil cache.read("foo")
    end
  end

  def test_read_multi_failure_returns_empty_hash
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    emulating_unavailability do |cache|
      assert_equal Hash.new, cache.read_multi("foo", "baz")
    end
  end

  def test_write_failure_returns_false
    emulating_unavailability do |cache|
      assert_equal false, cache.write("foo", "bar")
    end
  end

  def test_write_multi_failure_not_raises
    emulating_unavailability do |cache|
      assert_nothing_raised do
        cache.write_multi("foo" => "bar", "baz" => "quux")
      end
    end
  end

  def test_fetch_multi_failure_returns_fallback_results
    @cache.write_multi("foo" => "bar", "baz" => "quux")

    emulating_unavailability do |cache|
      fetched = cache.fetch_multi("foo", "baz") { |k| "unavailable" }
      assert_equal Hash["foo" => "unavailable", "baz" => "unavailable"], fetched
    end
  end

  def test_delete_failure_returns_false
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      assert_equal false, cache.delete("foo")
    end
  end

  def test_exist_failure_returns_false
    @cache.write("foo", "bar")

    emulating_unavailability do |cache|
      assert_not cache.exist?("foo")
    end
  end

  def test_increment_failure_returns_nil
    @cache.write("foo", 1, raw: true)

    emulating_unavailability do |cache|
      assert_nil cache.increment("foo")
    end
  end

  def test_decrement_failure_returns_nil
    @cache.write("foo", 1, raw: true)

    emulating_unavailability do |cache|
      assert_nil cache.decrement("foo")
    end
  end

  def test_clear_failure_returns_nil
    emulating_unavailability do |cache|
      assert_nil cache.clear
    end
  end
end
