# frozen_string_literal: true

module CacheStoreVersionBehavior
  ModelWithKeyAndVersion = Struct.new(:cache_key, :cache_version)

  def test_fetch_with_right_version_should_hit
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @cache.fetch(key, version: 1) { value }
    assert_equal value, @cache.read(key, version: 1)
  end

  def test_fetch_with_wrong_version_should_miss
    key = SecureRandom.uuid

    @cache.fetch(key, version: 1) { SecureRandom.alphanumeric }
    assert_nil @cache.read(key, version: 2)
  end

  def test_read_with_right_version_should_hit
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @cache.write(key, value, version: 1)
    assert_equal value, @cache.read(key, version: 1)
  end

  def test_read_with_wrong_version_should_miss
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @cache.write(key, value, version: 1)
    assert_nil @cache.read(key, version: 2)
  end

  def test_exist_with_right_version_should_be_true
    key = SecureRandom.uuid

    @cache.write(key, SecureRandom.alphanumeric, version: 1)
    assert @cache.exist?(key, version: 1)
  end

  def test_exist_with_wrong_version_should_be_false
    key = SecureRandom.uuid

    @cache.write(key, SecureRandom.alphanumeric, version: 1)
    assert_not @cache.exist?(key, version: 2)
  end

  def test_reading_and_writing_with_model_supporting_cache_version
    model_name = SecureRandom.alphanumeric

    m1v1 = ModelWithKeyAndVersion.new("#{model_name}/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("#{model_name}/1", 2)

    value = SecureRandom.alphanumeric

    @cache.write(m1v1, value)
    assert_equal value, @cache.read(m1v1)
    assert_nil @cache.read(m1v2)
  end

  def test_reading_and_writing_with_model_supporting_cache_version_using_nested_key
    model_name = SecureRandom.alphanumeric

    m1v1 = ModelWithKeyAndVersion.new("#{model_name}/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("#{model_name}/1", 2)

    value = SecureRandom.alphanumeric

    @cache.write([ "something", m1v1 ], value)
    assert_equal value, @cache.read([ "something", m1v1 ])
    assert_nil @cache.read([ "something", m1v2 ])
  end

  def test_fetching_with_model_supporting_cache_version
    model_name = SecureRandom.alphanumeric

    m1v1 = ModelWithKeyAndVersion.new("#{model_name}/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("#{model_name}/1", 2)

    value = SecureRandom.alphanumeric
    other_value = SecureRandom.alphanumeric

    @cache.fetch(m1v1) { value }
    assert_equal value, @cache.fetch(m1v1) { other_value }
    assert_equal other_value, @cache.fetch(m1v2) { other_value }
  end

  def test_exist_with_model_supporting_cache_version
    model_name = SecureRandom.alphanumeric

    m1v1 = ModelWithKeyAndVersion.new("#{model_name}/1", 1)
    m1v2 = ModelWithKeyAndVersion.new("#{model_name}/1", 2)

    value = SecureRandom.alphanumeric

    @cache.write(m1v1, value)
    assert @cache.exist?(m1v1)
    assert_not @cache.fetch(m1v2)
  end

  def test_fetch_multi_with_model_supporting_cache_version
    model_name = SecureRandom.alphanumeric

    m1v1 = ModelWithKeyAndVersion.new("#{model_name}/1", 1)
    m2v1 = ModelWithKeyAndVersion.new("#{model_name}/2", 1)
    m2v2 = ModelWithKeyAndVersion.new("#{model_name}/2", 2)

    first_fetch_values  = @cache.fetch_multi(m1v1, m2v1) { |m| m.cache_key }
    second_fetch_values = @cache.fetch_multi(m1v1, m2v2) { |m| m.cache_key + " 2nd" }

    assert_equal({ m1v1 => "#{model_name}/1", m2v1 => "#{model_name}/2" }, first_fetch_values)
    assert_equal({ m1v1 => "#{model_name}/1", m2v2 => "#{model_name}/2 2nd" }, second_fetch_values)
  end

  def test_version_is_normalized
    key = SecureRandom.uuid
    value = SecureRandom.alphanumeric

    @cache.write(key, value, version: 1)
    assert_equal value, @cache.read(key, version: "1")
  end
end
