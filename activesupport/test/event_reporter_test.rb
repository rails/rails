# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/event_reporter/test_helper"
require "json"

module ActiveSupport
  class EventReporterTest < ActiveSupport::TestCase
    include EventReporter::TestHelper

    setup do
      @subscriber = EventReporter::TestHelper::EventSubscriber.new
      @reporter = EventReporter.new(@subscriber, raise_on_error: true)
      @old_debug_mode = @reporter.debug_mode?
      @reporter.debug_mode = false
    end

    teardown do
      @reporter.debug_mode = @old_debug_mode
    end

    class TestEvent
      def initialize(data)
        @data = data
      end
    end

    class HttpRequestTag
      def initialize(http_method, http_status)
        @http_method = http_method
        @http_status = http_status
      end
    end

    class LoggingAbstraction
      def initialize(reporter)
        @reporter = reporter
      end

      def a_log_method(message)
        @reporter.notify(:custom_event, caller_depth: 2, message: message)
      end

      def a_debug_method(message)
        @reporter.debug(:custom_event, caller_depth: 2, message: message)
      end
    end

    class ErrorSubscriber
      def emit(event)
        raise StandardError.new("Uh oh!")
      end
    end

    test "#subscribe" do
      reporter = ActiveSupport::EventReporter.new
      subscribers = reporter.subscribe(@subscriber)
      assert_equal([{ subscriber: @subscriber, filter: nil }], subscribers)
    end

    test "#subscribe with filter" do
      reporter = ActiveSupport::EventReporter.new

      filter = ->(event) { event[:name].start_with?("user.") }
      subscribers = reporter.subscribe(@subscriber, &filter)

      assert_equal([{ subscriber: @subscriber, filter: filter }], subscribers)
    end

    test "#subscribe raises ArgumentError when sink doesn't respond to emit" do
      invalid_subscriber = Object.new

      error = assert_raises(ArgumentError) do
        @reporter.subscribe(invalid_subscriber)
      end

      assert_equal "Event subscriber Object must respond to #emit", error.message
    end

    test "#unsubscribe" do
      first_subscriber = @subscriber
      second_subscriber = EventSubscriber.new

      @reporter.subscribe(second_subscriber)
      @reporter.notify(:test_event, key: "value")

      assert event_matcher(name: "test_event", payload: { key: "value" }).call(second_subscriber.events.last)

      @reporter.unsubscribe(second_subscriber)

      assert_not_called(second_subscriber, :emit, [
        event_matcher(name: "another_event")
      ]) do
        @reporter.notify(:another_event, key: "value")
      end

      assert event_matcher(name: "another_event", payload: { key: "value" }).call(first_subscriber.events.last)

      @reporter.unsubscribe(EventSubscriber)
      @reporter.notify(:last_event, key: "value")

      assert_empty first_subscriber.events.select(&event_matcher(name: "last_event", payload: { key: "value" }))
      assert_empty second_subscriber.events.select(&event_matcher(name: "last_event", payload: { key: "value" }))
    end

    test "#notify with name" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event")
      ]) do
        @reporter.notify(:test_event)
      end
    end

    test "#notify filters" do
      reporter = ActiveSupport::EventReporter.new
      reporter.subscribe(@subscriber) { |event| event[:name].start_with?("user_") }

      assert_not_called(@subscriber, :emit) do
        reporter.notify(:test_event)
      end

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "user_event")
      ]) do
        reporter.notify(:user_event)
      end
    end

    test "#notify with name and hash payload" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" })
      ]) do
        @reporter.notify(:test_event, { key: "value" })
      end
    end

    test "#notify with name and kwargs" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" })
      ]) do
        @reporter.notify(:test_event, key: "value")
      end
    end

    test "#notify symbolizes keys in hash payload" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" })
      ]) do
        @reporter.notify(:test_event, { "key" => "value" })
      end
    end

    test "#notify with hash payload and kwargs raises" do
      error = assert_raises(ArgumentError) do
        @reporter.notify(:test_event, { key: "value" }, extra: "arg")
      end

      assert_match(
        /Rails.event.notify accepts either an event object, a payload hash, or keyword arguments/,
        error.message
      )
    end

    test "#notify includes source location in event payload" do
      filepath = __FILE__
      lineno = __LINE__ + 4
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", source_location: { filepath:, lineno: })
      ]) do
        @reporter.notify("test_event")
      end
    end

    test "#notify with caller depth option" do
      logging_abstraction = LoggingAbstraction.new(@reporter)
      filepath = __FILE__
      lineno = __LINE__ + 4
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "custom_event", payload: { message: "hello" }, source_location: { filepath:, lineno: })
      ]) do
        logging_abstraction.a_log_method("hello")
      end
    end

    test "#notify with event object" do
      event = TestEvent.new("value")

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: TestEvent.name, payload: event)
      ]) do
        @reporter.notify(event)
      end
    end

    test "#notify with event object and kwargs raises when raise_on_error is true" do
      event = TestEvent.new("value")
      error = assert_raises(ArgumentError) do
        @reporter.notify(event, extra: "arg")
      end

      assert_match(
        /Rails.event.notify accepts either an event object, a payload hash, or keyword arguments/,
        error.message
      )
    end

    test "#notify with event object and hash payload raises when raise_on_error is true" do
      event = TestEvent.new("value")
      error = assert_raises(ArgumentError) do
        @reporter.notify(event, { extra: "arg" })
      rescue RailsStrictWarnings::WarningError => _e
        # Expected warning
      end

      assert_match(
        /Rails.event.notify accepts either an event object, a payload hash, or keyword arguments/,
        error.message
      )
    end

    test "#notify with event object and kwargs warns when raise_on_error is false" do
      @reporter = EventReporter.new(@subscriber, raise_on_error: false)

      event = TestEvent.new("value")

      error_report = assert_error_reported do
        assert_called_with(@subscriber, :emit, [event_matcher(name: TestEvent.name, payload: event)]) do
          @reporter.notify(event, extra: "arg")
        end
      end

      err = error_report.error.message
      assert_match(/Rails.event.notify accepts either an event object, a payload hash, or keyword arguments/, err)
    end

    test "#notify warns about subscriber errors when raise_on_error is false" do
      @reporter = EventReporter.new(@subscriber, raise_on_error: false)

      @reporter.subscribe(ErrorSubscriber.new)

      error_report = assert_error_reported do
        @reporter.notify(:test_event)
      end
      assert_equal "Uh oh!", error_report.error.message
    end

    test "#notify raises subscriber errors when raise_on_error is true" do
      @reporter.subscribe(ErrorSubscriber.new)

      error = assert_raises(StandardError) do
        @reporter.notify(:test_event)
      end

      assert_equal("Uh oh!", error.message)
    end

    test "#notify with filtered payloads" do
      filter = ActiveSupport::ParameterFilter.new([:zomg], mask: "[FILTERED]")
      @reporter.stub(:payload_filter, filter) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value", zomg: "[FILTERED]" })
        ]) do
          @reporter.notify(:test_event, { key: "value", zomg: "secret" })
        end
      end
    end

    test "#notify with filter_payload: false skips payload filtering" do
      filter = ActiveSupport::ParameterFilter.new([:name], mask: "[FILTERED]")
      @reporter.stub(:payload_filter, filter) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { name: "Person Load", sql: "SELECT 1" })
        ]) do
          @reporter.notify(:test_event, filter_payload: false, name: "Person Load", sql: "SELECT 1")
        end
      end
    end

    test "#notify with filter_payload: false and hash payload skips filtering" do
      filter = ActiveSupport::ParameterFilter.new([:name], mask: "[FILTERED]")
      @reporter.stub(:payload_filter, filter) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { name: "Person Load" })
        ]) do
          @reporter.notify(:test_event, { name: "Person Load" }, filter_payload: false)
        end
      end
    end

    test "#debug with filter_payload: false skips payload filtering" do
      filter = ActiveSupport::ParameterFilter.new([:name], mask: "[FILTERED]")
      @reporter.stub(:payload_filter, filter) do
        @reporter.with_debug do
          assert_called_with(@subscriber, :emit, [
            event_matcher(name: "test_event", payload: { name: "Person Load" })
          ]) do
            @reporter.debug(:test_event, filter_payload: false, name: "Person Load")
          end
        end
      end
    end

    test "default filter_parameters is used by default" do
      old_filter_parameters = ActiveSupport.filter_parameters
      ActiveSupport.filter_parameters = [:secret]

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value", secret: "[FILTERED]" })
      ]) do
        @reporter.notify(:test_event, { key: "value", secret: "hello" })
      end
    ensure
      ActiveSupport.filter_parameters = old_filter_parameters
    end

    test ".filter_parameters is used when present" do
      old_filter_parameters = EventReporter.filter_parameters
      EventReporter.filter_parameters = [:foo]

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value", foo: "[FILTERED]" })
      ]) do
        @reporter.notify(:test_event, { key: "value", foo: "hello" })
      end
    ensure
      EventReporter.filter_parameters = old_filter_parameters
    end

    test "#with_debug" do
      @reporter.with_debug do
        assert_predicate @reporter, :debug_mode?
      end
      assert_not_predicate @reporter, :debug_mode?
    end

    test "#debug_mode? returns true by default" do
      assert @old_debug_mode
    end

    test "#debug_mode? returns true when debug_mode=true is set" do
      @reporter.debug_mode = true
      assert_predicate @reporter, :debug_mode?
    end

    test "#with_debug works with nested calls" do
      @reporter.with_debug do
        assert_predicate @reporter, :debug_mode?

        @reporter.with_debug do
          assert_predicate @reporter, :debug_mode?
        end

        assert_predicate @reporter, :debug_mode?
      end
    end

    test "#debug emits when in debug mode" do
      @reporter.with_debug do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" })
        ]) do
          @reporter.debug(:test_event, key: "value")
        end
      end
    end

    test "#debug with caller depth" do
      logging_abstraction = LoggingAbstraction.new(@reporter)
      filepath = __FILE__
      lineno = __LINE__ + 4
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "custom_event", payload: { message: "hello" }, source_location: { filepath:, lineno: })
      ]) do
        @reporter.with_debug { logging_abstraction.a_debug_method("hello") }
      end
    end

    test "#debug emits in debug mode with block" do
      @reporter.with_debug do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { slow_to_compute: "value" })
        ]) do
          @reporter.debug(:test_event) do
            { slow_to_compute: "value" }
          end
        end
      end
    end

    test "#debug does not emit when not in debug mode" do
      assert_not_called(@subscriber, :emit) do
        @reporter.debug(:test_event, key: "value")
      end
    end

    test "#debug with block merges kwargs" do
      @reporter.with_debug do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value", slow_to_compute: "another_value" })
        ]) do
          @reporter.debug(:test_event, key: "value") do
            { slow_to_compute: "another_value" }
          end
        end
      end
    end

    test "#tagged adds tags to the emitted event" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" }, tags: { section: "admin" })
      ]) do
        @reporter.tagged(section: "admin") do
          @reporter.notify(:test_event, key: "value")
        end
      end

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" }, tags: { section: "checkouts" })
      ]) do
        @reporter.tagged({ section: "checkouts" }) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "#tagged with nested tags" do
      @reporter.tagged(section: "admin") do
        @reporter.tagged(nested: "tag") do
          assert_called_with(@subscriber, :emit, [
            event_matcher(name: "test_event", payload: { key: "value" }, tags: { section: "admin", nested: "tag" })
          ]) do
            @reporter.notify(:test_event, key: "value")
          end
        end
        @reporter.tagged(hello: "world") do
          assert_called_with(@subscriber, :emit, [
            event_matcher(name: "test_event", payload: { key: "value" }, tags: { section: "admin", hello: "world" })
          ]) do
            @reporter.notify(:test_event, key: "value")
          end
        end
      end
    end

    test "#tagged with boolean tags" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" }, tags: { is_for_testing: true })
      ]) do
        @reporter.tagged(:is_for_testing) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "#tagged can overwrite values on collision" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" }, tags: { section: "checkouts" })
      ]) do
        @reporter.tagged(section: "admin") do
          @reporter.tagged(section: "checkouts") do
            @reporter.notify(:test_event, key: "value")
          end
        end
      end
    end

    test "#tagged with tag object" do
      http_tag = HttpRequestTag.new("GET", 200)

      @reporter.tagged(http_tag) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { "#{HttpRequestTag.name}": http_tag })
        ]) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "#tagged with mixed tags" do
      http_tag = HttpRequestTag.new("GET", 200)
      @reporter.tagged("foobar", http_tag, shop_id: 123) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { foobar: true, "#{HttpRequestTag.name}": http_tag, shop_id: 123 })
        ]) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "#tagged copies tag stack from parent fiber without mutating parent's tag stack" do
      @reporter.tagged(shop_id: 999) do
        Fiber.new do
          @reporter.tagged(shop_id: 123) do
            assert_called_with(@subscriber, :emit, [
              event_matcher(name: "test_event", payload: { key: "value" }, tags: { shop_id: 123 })
            ]) do
              @reporter.notify(:test_event, key: "value")
            end
          end
        end.resume

        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "parent_event", payload: { key: "parent" }, tags: { shop_id: 999 })
        ]) do
          @reporter.notify(:parent_event, key: "parent")
        end
      end
    end

    test "#tagged maintains isolation between concurrent fibers" do
      @reporter.tagged(shop_id: 123) do
        fiber = Fiber.new do
          assert_called_with(@subscriber, :emit, [
            event_matcher(name: "child_event", payload: { key: "value" }, tags: { shop_id: 123 })
          ]) do
            @reporter.notify(:child_event, key: "value")
          end
        end

        @reporter.tagged(api_client_id: 456) do
          fiber.resume

          # Verify parent fiber has both tags
          assert_called_with(@subscriber, :emit, [
            event_matcher(name: "parent_event", payload: { key: "parent" }, tags: { shop_id: 123, api_client_id: 456 })
          ]) do
            @reporter.notify(:parent_event, key: "parent")
          end
        end
      end
    end
  end

  class ContextStoreTest < ActiveSupport::TestCase
    include EventReporter::TestHelper

    setup do
      @subscriber = EventReporter::TestHelper::EventSubscriber.new
      @reporter = EventReporter.new(@subscriber, raise_on_error: true)
    end

    teardown do
      EventContext.clear
    end

    test "#context returns empty hash by default" do
      assert_equal({}, @reporter.context)
    end

    test "#set_context sets context data" do
      @reporter.set_context(shop_id: 123)
      assert_equal({ shop_id: 123 }, @reporter.context)
    end

    test "#set_context merges with existing context" do
      @reporter.set_context(shop_id: 123)
      @reporter.set_context(user_id: 456)
      assert_equal({ shop_id: 123, user_id: 456 }, @reporter.context)
    end

    test "#set_context overwrites existing keys" do
      @reporter.set_context(shop_id: 123)
      @reporter.set_context(shop_id: 456)
      assert_equal({ shop_id: 456 }, @reporter.context)
    end

    test "#set_context with string keys converts them to symbols" do
      @reporter.set_context("shop_id" => 123)
      assert_equal({ shop_id: 123 }, @reporter.context)
    end

    test "#clear_context removes all context data" do
      @reporter.set_context(shop_id: 123, user_id: 456)
      @reporter.clear_context
      assert_equal({}, @reporter.context)
    end

    test "#notify includes context in event" do
      @reporter.set_context(shop_id: 123)

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", payload: { key: "value" }, tags: {}, context: { shop_id: 123 })
      ]) do
        @reporter.notify(:test_event, key: "value")
      end
    end

    test "#context inherited by child fibers without mutating parent's context" do
      @reporter.set_context(shop_id: 999)
      Fiber.new do
        @reporter.set_context(shop_id: 123)
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", context: { shop_id: 123 })
        ]) do
          @reporter.notify(:test_event)
        end
      end.resume

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "parent_event", payload: { key: "parent" }, context: { shop_id: 999 })
      ]) do
        @reporter.notify(:parent_event, key: "parent")
      end
    end

    test "#context isolated between concurrent fibers" do
      @reporter.set_context(shop_id: 123)
      fiber = Fiber.new do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "child_event", context: { shop_id: 123 })
        ]) do
          @reporter.notify(:child_event)
        end
      end

      @reporter.set_context(api_client_id: 456)
      fiber.resume

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "parent_event", context: { shop_id: 123, api_client_id: 456 })
      ]) do
        @reporter.notify(:parent_event)
      end
    end

    test "context is preserved when using #tagged" do
      @reporter.set_context(shop_id: 123)

      @reporter.tagged(request_id: "abc") do
        assert_equal({ shop_id: 123 }, @reporter.context)

        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { request_id: "abc" }, context: { shop_id: 123 })
        ]) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "payload filter reloading" do
      @reporter.notify(:some_event, test: true)
      ActiveSupport.filter_parameters << :param_to_be_filtered

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "some_event", payload: { param_to_be_filtered: "test" })
      ]) do
        @reporter.notify(:some_event, param_to_be_filtered: "test")
      end

      @reporter.reload_payload_filter

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "some_event", payload: { param_to_be_filtered: "[FILTERED]" })
      ]) do
        @reporter.notify(:some_event, param_to_be_filtered: "test")
      end
    ensure
      ActiveSupport.filter_parameters.pop
    end
  end

  class EncodersTest < ActiveSupport::TestCase
    class TestEvent
      def initialize(data)
        @data = data
      end

      def to_h
        { data: @data }
      end
    end

    class HttpRequestTag
      def initialize(http_method, http_status)
        @http_method = http_method
        @http_status = http_status
      end

      def to_h
        {
          http_method: @http_method,
          http_status: @http_status,
        }
      end
    end

    setup do
      @event = {
        name: "test_event",
        payload: { id: 123, message: "hello" },
        tags: { section: "admin" },
        context: { user_id: 456 },
        timestamp: 1738964843208679035,
        source_location: { filepath: "/path/to/file.rb", lineno: 42, label: "test_method" }
      }
    end
  end
end
