# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/test_adapters"

class TestAdaptersTest < ActiveSupport::TestCase
  class ExampleAdapter < ActionDispatch::SystemTesting::TestAdapter
  end

  test "lookup accepts registered adapter names as symbols and strings" do
    ActionDispatch::SystemTesting::TestAdapters.register(:lookup_example, ExampleAdapter)

    assert_same ExampleAdapter, ActionDispatch::SystemTesting::TestAdapters.lookup(:lookup_example)
    assert_same ExampleAdapter, ActionDispatch::SystemTesting::TestAdapters.lookup("lookup_example")
  end

  test "lookup rejects names that are not strings or symbols" do
    error = assert_raises(ArgumentError) do
      ActionDispatch::SystemTesting::TestAdapters.lookup(ExampleAdapter)
    end

    assert_equal "system test adapter name must be a String or Symbol", error.message
  end

  test "lookup raises AdapterNotFoundError for an unknown adapter" do
    error = assert_raises(ActionDispatch::SystemTesting::TestAdapters::AdapterNotFoundError) do
      ActionDispatch::SystemTesting::TestAdapters.lookup(:missing_test_adapter)
    end

    assert_equal "system test adapter not found: :missing_test_adapter", error.message
  end
end
