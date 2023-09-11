# frozen_string_literal: true

require "active_support/core_ext/object/with"

module CacheStoreFormatVersionBehavior
  extend ActiveSupport::Concern

  FORMAT_VERSION_SIGNATURES = {
    6.1 => [
      "\x04\x08o".b, # Marshal.dump(entry)
      "\x04\x08o".b, # Marshal.dump(entry.compressed(...))
    ],
    7.0 => [
      "\x00\x04\x08[".b, # "\x00" + Marshal.dump(entry.pack)
      "\x01\x78".b,      # "\x01" + Zlib::Deflate.deflate(...)
    ],
    7.1 => [
      "\x00\x11\x01".b, # ActiveSupport::Cache::Coder#dump
      "\x00\x11\x81".b, # ActiveSupport::Cache::Coder#dump_compressed
    ],
  }

  FORMAT_VERSIONS = FORMAT_VERSION_SIGNATURES.keys

  included do
    test "format version affects default coder" do
      coders = FORMAT_VERSIONS.map do |format_version|
        with_format(format_version) do
          lookup_store.instance_variable_get(:@coder)
        end
      end

      assert_equal coders, coders.uniq
    end

    test "invalid format version raises" do
      with_format(0) do
        assert_raises do
          lookup_store
        end
      end
    end

    FORMAT_VERSION_SIGNATURES.each do |format_version, (uncompressed_signature, compressed_signature)|
      test "format version #{format_version.inspect} uses correct signature for uncompressed entries" do
        serialized = with_format(format_version) do
          lookup_store.send(:serialize_entry, ActiveSupport::Cache::Entry.new(["value"] * 100))
        end

        skip if !serialized.is_a?(String)

        assert_operator serialized, :start_with?, uncompressed_signature
      end

      test "format version #{format_version.inspect} uses correct signature for compressed entries" do
        serialized = with_format(format_version) do
          lookup_store.send(:serialize_entry, ActiveSupport::Cache::Entry.new(["value"] * 100), compress_threshold: 1)
        end

        skip if !serialized.is_a?(String)

        assert_operator serialized, :start_with?, compressed_signature
      end

      test "Marshal undefined class/module deserialization error with #{format_version} format" do
        key = "marshal-#{rand}"
        self.class.const_set(:Foo, Class.new)
        @store = with_format(format_version) { lookup_store }
        @store.write(key, self.class::Foo.new)
        assert_instance_of self.class::Foo, @store.read(key)

        self.class.send(:remove_const, :Foo)
        assert_nil @store.read(key)
        assert_equal false, @store.exist?(key)
      ensure
        self.class.send(:remove_const, :Foo) rescue nil
      end
    end

    FORMAT_VERSIONS.product(FORMAT_VERSIONS) do |read_version, write_version|
      test "format version #{read_version.inspect} can read #{write_version.inspect} entries" do
        key = SecureRandom.uuid

        with_format(write_version) do
          lookup_store.write(key, "value for #{key}")
        end

        with_format(read_version) do
          assert_equal "value for #{key}", lookup_store.read(key)
        end
      end

      test "format version #{read_version.inspect} can read #{write_version.inspect} entries with compression" do
        key = SecureRandom.uuid

        with_format(write_version) do
          lookup_store(compress_threshold: 1).write(key, key * 10)
        end

        with_format(read_version) do
          assert_equal key * 10, lookup_store.read(key)
        end
      end
    end
  end

  private
    def with_format(format_version, &block)
      if format_version == 6.1
        assert_deprecated(ActiveSupport.deprecator) do
          ActiveSupport::Cache.with(format_version: format_version, &block)
        end
      else
        ActiveSupport::Cache.with(format_version: format_version, &block)
      end
    end
end
