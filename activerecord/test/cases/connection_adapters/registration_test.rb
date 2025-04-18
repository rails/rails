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
          ActiveRecord::ConnectionAdapters.resolve("fake_legacy")
        end

        assert_equal(
          "Database configuration specifies nonexistent 'fake_legacy' adapter. Available adapters are: abstract, fake, mysql2, postgresql, sqlite3, trilogy. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile if it's not in the list of available adapters.",
          exception.message
        )
      ensure
        ActiveRecord::ConnectionAdapters.instance_variable_get(:@adapters).delete("fake_legacy")
      end
    end
  end
end
