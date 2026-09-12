# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/test_adapter"

class TestAdapterTest < ActiveSupport::TestCase
  class TestCase
    def base_url
      "http://example.test"
    end
  end

  test "global and test helpers resolve keyword dependencies" do
    events = []
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      global_helper :browser do
        events << :open_browser
        on_teardown { events << :close_browser }
        :browser
      end

      global_helper :browser_context do |base_url:, browser:|
        events << [:open_context, base_url, browser]
        on_teardown { events << :close_context }
        :browser_context
      end

      helper :page do |browser_context:|
        events << [:open_page, browser_context]
        on_teardown { events << :close_page }
        Object.new
      end
    end

    adapter = adapter_class.new
    adapter.install(TestCase)

    first_test = TestCase.new
    adapter.before_setup
    first_page = first_test.page

    assert_same first_page, first_test.page
    assert_equal [
      :open_browser,
      [:open_context, "http://example.test", :browser],
      [:open_page, :browser_context],
    ], events

    adapter.after_teardown

    second_test = TestCase.new
    adapter.before_setup
    second_page = second_test.page
    adapter.after_teardown

    assert_not_same first_page, second_page
    assert_equal 1, events.count(:open_browser)
    assert_equal 0, events.count(:close_context)
    assert_equal 2, events.count(:close_page)

    adapter.shutdown

    assert_equal [:close_context, :close_browser], events.last(2)
  end

  test "test helpers can depend on other test helpers" do
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper(:one) { 1 }
      helper(:two) { |one:| one + 1 }
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup

    assert_equal 2, test_case.two
  ensure
    adapter&.after_teardown if test_case
    adapter&.shutdown
  end

  test "adapters cannot be subclassed" do
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter)

    error = assert_raises(TypeError) { Class.new(adapter_class) }
    assert_equal "system test adapters cannot be subclassed; inherit directly from ActionDispatch::SystemTesting::TestAdapter", error.message
  end

  test "helpers must declare dependencies as required keyword arguments" do
    error = assert_raises(ArgumentError) do
      Class.new(ActionDispatch::SystemTesting::TestAdapter) do
        helper(:value) { |missing: :default| missing }
      end
    end

    assert_equal "system test helper :value must declare its dependencies as required keyword arguments", error.message
  end

  test "global helpers cannot depend on test helpers" do
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper(:page) { :page }
      global_helper(:browser) { |page:| page }
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup

    error = assert_raises(ArgumentError) { test_case.browser }
    assert_equal "global system test helper cannot depend on test helper :page", error.message
  ensure
    adapter&.after_teardown if test_case
    adapter&.shutdown
  end

  test "circular helper dependencies raise a descriptive error" do
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper(:a) { |b:| b }
      helper(:b) { |c:| c }
      helper(:c) { |d:| d }
      helper(:d) { |a:| a }
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup

    error = assert_raises(ArgumentError) { test_case.a }
    assert_equal "circular system test helper dependency: a -> b -> c -> d -> a", error.message
  ensure
    adapter&.after_teardown if test_case
    adapter&.shutdown
  end

  test "unknown required dependencies raise a descriptive error" do
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper(:page) { |missing:| missing }
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup

    error = assert_raises(ArgumentError) { test_case.page }
    assert_equal "system test helper :page has an unknown dependency :missing", error.message
  ensure
    adapter&.after_teardown if test_case
    adapter&.shutdown
  end

  test "registered teardown callbacks run when helper initialization fails" do
    events = []
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper :page do
        on_teardown { events << :closed }
        raise "failed to open page"
      end
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup

    error = assert_raises(RuntimeError) { test_case.page }
    assert_equal "failed to open page", error.message
    assert_equal [:closed], events
  ensure
    adapter&.after_teardown if test_case
    adapter&.shutdown
  end

  test "all teardown callbacks run when one raises" do
    events = []
    adapter_class = Class.new(ActionDispatch::SystemTesting::TestAdapter) do
      helper :page do
        on_teardown { events << :last }
        on_teardown do
          events << :first
          raise "failed to close"
        end
        :page
      end
    end
    adapter = adapter_class.new
    adapter.install(TestCase)
    test_case = TestCase.new
    adapter.before_setup
    test_case.page

    error = assert_raises(RuntimeError) { adapter.after_teardown }

    assert_equal "failed to close", error.message
    assert_equal [:first, :last], events
  ensure
    adapter&.shutdown
  end

  test "on_teardown is only exposed while initializing a helper" do
    adapter = ActionDispatch::SystemTesting::TestAdapter.new

    assert_not_respond_to adapter, :on_teardown
  ensure
    adapter&.shutdown
  end
end
