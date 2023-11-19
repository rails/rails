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
        assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("fake").name
      end

      test "#register allows for symbol key" do
        assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        ActiveRecord::ConnectionAdapters.register(:fake, "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("fake").name
      end

      test "#resolve allows for symbol key" do
        assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.resolve("fake")
        end

        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)

        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve(:fake).name
      end

      test "#alias registers a new adapter alias with the same class and location as the original" do
        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)
        ActiveRecord::ConnectionAdapters.alias("fake", as: "potato")
        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("potato").name
      end

      test "#alias accepts symbol keys" do
        ActiveRecord::ConnectionAdapters.register("fake", "FakeActiveRecordAdapter", @fake_adapter_path)
        ActiveRecord::ConnectionAdapters.alias(:fake, as: :potato)
        assert_equal "FakeActiveRecordAdapter", ActiveRecord::ConnectionAdapters.resolve("potato").name
      end

      test "#alias raises if the original is invalid" do
        assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::ConnectionAdapters.alias("carrot", as: "potato")
        end
      end
    end
  end
end
