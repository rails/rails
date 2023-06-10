# frozen_string_literal: true

require "active_support/core_ext/numeric/bytes"

module CacheStoreCompressionBehavior
  extend ActiveSupport::Concern

  included do
    test "compression by default" do
      @cache = lookup_store

      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT
      if compression_always_disabled_by_default?
        assert_uncompressed LARGE_STRING
        assert_uncompressed LARGE_OBJECT
      else
        assert_compressed LARGE_STRING
        assert_compressed LARGE_OBJECT
      end
    end

    test "compression can be disabled" do
      @cache = lookup_store(compress: false)

      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT
      assert_uncompressed LARGE_STRING
      assert_uncompressed LARGE_OBJECT
    end

    test ":compress method option overrides initializer option" do
      @cache = lookup_store(compress: true)

      assert_uncompressed SMALL_STRING, compress: false
      assert_uncompressed SMALL_OBJECT, compress: false
      assert_uncompressed LARGE_STRING, compress: false
      assert_uncompressed LARGE_OBJECT, compress: false

      @cache = lookup_store(compress: false)

      assert_uncompressed SMALL_STRING, compress: true
      assert_uncompressed SMALL_OBJECT, compress: true
      assert_compressed LARGE_STRING, compress: true
      assert_compressed LARGE_OBJECT, compress: true
    end

    test "low :compress_threshold triggers compression" do
      @cache = lookup_store(compress: true, compress_threshold: 1)

      assert_compressed SMALL_STRING
      assert_compressed SMALL_OBJECT
      assert_compressed LARGE_STRING
      assert_compressed LARGE_OBJECT
    end

    test "high :compress_threshold inhibits compression" do
      @cache = lookup_store(compress: true, compress_threshold: 1.megabyte)

      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT
      assert_uncompressed LARGE_STRING
      assert_uncompressed LARGE_OBJECT
    end

    test ":compress_threshold method option overrides initializer option" do
      @cache = lookup_store(compress: true, compress_threshold: 1)

      assert_uncompressed SMALL_STRING, compress_threshold: 1.megabyte
      assert_uncompressed SMALL_OBJECT, compress_threshold: 1.megabyte
      assert_uncompressed LARGE_STRING, compress_threshold: 1.megabyte
      assert_uncompressed LARGE_OBJECT, compress_threshold: 1.megabyte

      @cache = lookup_store(compress: true, compress_threshold: 1.megabyte)

      assert_compressed SMALL_STRING, compress_threshold: 1
      assert_compressed SMALL_OBJECT, compress_threshold: 1
      assert_compressed LARGE_STRING, compress_threshold: 1
      assert_compressed LARGE_OBJECT, compress_threshold: 1
    end

    test "compression ignores nil" do
      assert_uncompressed nil
      assert_uncompressed nil, compress: true, compress_threshold: 1
    end

    test "compression ignores incompressible data" do
      assert_uncompressed "", compress: true, compress_threshold: 1
      assert_uncompressed [*0..127].pack("C*"), compress: true, compress_threshold: 1
    end
  end

  private
    # Use strings that are guaranteed to compress well, so we can easily tell if
    # the compression kicked in or not.
    SMALL_STRING = "0" * 100
    LARGE_STRING = "0" * 2.kilobytes

    SMALL_OBJECT = { data: SMALL_STRING }
    LARGE_OBJECT = { data: LARGE_STRING }

    def assert_compressed(value, **options)
      assert_operator compute_entry_size_reduction(value, **options), :>, 0
    end

    def assert_uncompressed(value, **options)
      assert_equal 0, compute_entry_size_reduction(value, **options)
    end

    def compute_entry_size_reduction(value, **options)
      entry = ActiveSupport::Cache::Entry.new(value)

      uncompressed = @cache.send(:serialize_entry, entry, **options, compress: false)
      actual = @cache.send(:serialize_entry, entry, **options)

      uncompressed.bytesize - actual.bytesize
    end

    def compression_always_disabled_by_default?
      false
    end
end
