# frozen_string_literal: true

require "active_support/core_ext/object/with"

module CacheStoreFormatVersionBehavior
  extend ActiveSupport::Concern

  FORMAT_VERSIONS = [6.1, 7.0, :message_pack]

  included do
    test "format version affects default coder" do
      coders = FORMAT_VERSIONS.map do |format_version|
        ActiveSupport::Cache.with(format_version: format_version) do
          lookup_store.instance_variable_get(:@coder)
        end
      end

      assert_equal coders, coders.uniq
    end

    test "invalid format version raises" do
      ActiveSupport::Cache.with(format_version: 0) do
        assert_raises do
          lookup_store
        end
      end
    end

    FORMAT_VERSIONS.product(FORMAT_VERSIONS) do |read_version, write_version|
      test "format version #{read_version.inspect} can read #{write_version.inspect} entries" do
        key = SecureRandom.uuid

        ActiveSupport::Cache.with(format_version: write_version) do
          lookup_store.write(key, "value for #{key}")
        end

        ActiveSupport::Cache.with(format_version: read_version) do
          assert_equal "value for #{key}", lookup_store.read(key)
        end
      end

      test "format version #{read_version.inspect} can read #{write_version.inspect} entries with compression" do
        key = SecureRandom.uuid

        ActiveSupport::Cache.with(format_version: write_version) do
          lookup_store(compress_threshold: 1).write(key, key * 10)
        end

        ActiveSupport::Cache.with(format_version: read_version) do
          assert_equal key * 10, lookup_store.read(key)
        end
      end
    end
  end
end
