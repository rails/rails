# frozen_string_literal: true

module CacheStoreVersionBehavior
  ModelWithKeyAndVersion = Struct.new(:cache_key, :cache_version)

  def test_fetch_with_right_version_should_hit
    @cache.fetch("foo", version: 1) { "bar" }
    assert_equal "bar", @cache.read("foo", version: 1)
  end

  def test_fetch_with_wrong_version_should_miss
    @cache.fetch("foo", version: 1) { "bar" }
    assert_nil @cache.read("foo", version: 2)
  end

  def test_read_with_right_version_should_hit
    @cache.write("foo", "bar", version: 1)
    assert_equal "bar", @cache.read("foo", version: 1)
  end

  def test_read_with_wrong_version_should_miss
    @cache.write("foo", "bar", version: 1)
    assert_nil @cache.read("foo", version: 2)
  end

  def test_exist_with_right_version_should_be_true
    @cache.write("foo", "bar", version: 1)
    assert @cache.exist?("foo", version: 1)
  end

  def test_exist_with_wrong_version_should_be_false
    @cache.write("foo", "bar", version: 1)
    assert !@cache.exist?("foo", version: 2)
  end

  def test_reading_and_writing_with_model_supporting_cache_version
    m1v1 = ModelWithKeyAndVersion.new("model/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("model/1", 2)

    @cache.write(m1v1, "bar")
    assert_equal "bar", @cache.read(m1v1)
    assert_nil @cache.read(m1v2)
  end

  def test_reading_and_writing_with_model_supporting_cache_version_using_nested_key
    m1v1 = ModelWithKeyAndVersion.new("model/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("model/1", 2)

    @cache.write([ "something", m1v1 ], "bar")
    assert_equal "bar", @cache.read([ "something", m1v1 ])
    assert_nil @cache.read([ "something", m1v2 ])
  end

  def test_fetching_with_model_supporting_cache_version
    m1v1 = ModelWithKeyAndVersion.new("model/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("model/1", 2)

    @cache.fetch(m1v1) { "bar" }
    assert_equal "bar", @cache.fetch(m1v1) { "bu" }
    assert_equal "bu", @cache.fetch(m1v2) { "bu" }
  end

  def test_exist_with_model_supporting_cache_version
    m1v1 = ModelWithKeyAndVersion.new("model/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("model/1", 2)

    @cache.write(m1v1, "bar")
    assert     @cache.exist?(m1v1)
    assert_not @cache.fetch(m1v2)
  end

  def test_fetch_multi_with_model_supporting_cache_version
    m1v1 = ModelWithKeyAndVersion.new("model/1", 1)
    m2v1 = ModelWithKeyAndVersion.new("model/2", 1)
    m2v2 = ModelWithKeyAndVersion.new("model/2", 2)

    first_fetch_values  = @cache.fetch_multi(m1v1, m2v1) { |m| m.cache_key }
    second_fetch_values = @cache.fetch_multi(m1v1, m2v2) { |m| m.cache_key + " 2nd" }

    assert_equal({ m1v1 => "model/1", m2v1 => "model/2" }, first_fetch_values)
    assert_equal({ m1v1 => "model/1", m2v2 => "model/2 2nd" }, second_fetch_values)
  end

  def test_version_is_normalized
    @cache.write("foo", "bar", version: 1)
    assert_equal "bar", @cache.read("foo", version: "1")
  end
end
