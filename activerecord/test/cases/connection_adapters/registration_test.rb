# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class RegistrationTest < ActiveRecord::TestCase
      def setup
        @original_adapters = ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).dup
        ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).delete("fake")
        @fake_adapter_path = File.expand_path("../../support/fake_adapter.rb", __dir__)
      end

      def teardown
        ActiveRecord::ConnectionAdapters.instance_variable_set(:@adapters, @original_adapters)
      end

      test "#register registers a new database adapter and #resolve can find it and raises if it cannot" do
        exception = assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        assert_match(
          /Database configuration specifies nonexistent 'fake' adapter. Available adapters are:/,
          exception.message
        )

        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("fake").name
      end

      test "#register allows for symbol key" do
        exception = assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        assert_match(
          /Database configuration specifies nonexistent 'fake' adapter. Available adapters are:/,
          exception.message
        )

        ActiveRecord::ConnectionAdapters.register(:fake, "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("fake").name
      end

      test "#resolve allows for symbol key" do
        exception = assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        assert_match(
          /Database configuration specifies nonexistent 'fake' adapter. Available adapters are:/,
          exception.message
        )

        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve(:fake).name
      end
    end

    class RegistrationIsolatedTest < ActiveRecord::TestCase
      include ActiveSupport::Testing::Isolation

      def setup
        @original_adapters = ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).dup
      end

      test "#resolve raises if the adapter is using the pre 7.2 adapter registration API" do
        exception = assert_raises(ActiveRecord::AdapterNotFound) do
          assert_deprecated(ActiveRecord.deprecator) do
            ActiveRecord::ConnectionAdapters.resolve("fake_legacy")
          end
        end

        assert_match(
          /Database configuration specifies 'fake_legacy' adapter but that adapter has not been registered. Ensure that the adapter in the Gemfile is at the latest version. If it is, then the adapter may need to be modified./,
          exception.message
        )
      ensure
        ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).delete("fake_legacy")
      end

      test "#resolve raises if the adapter maybe is using the pre 7.2 adapter registration API but we are not sure" do
        exception = assert_raises(ActiveRecord::AdapterNotFound) do
          assert_deprecated(ActiveRecord.deprecator) do
            ActiveRecord::ConnectionAdapters.resolve("fake_misleading_legacy")
          end
        end

        assert_match(
          /Database configuration specifies nonexistent 'fake_misleading_legacy' adapter. Available adapters are:/,
          exception.message
        )

        assert_match(
          /Ensure that the adapter is spelled correctly in config\/database.yml and that you've added the necessary adapter gem to your Gemfile and that it is at its latest version. If it is up to date, the adapter may need to be modified./,
          exception.message
        )
      ensure
        ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).delete("fake_misleading_legacy")
      end
    end
  end
end
