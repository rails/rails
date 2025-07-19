# typed: true
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
    end

    TestEvent = Class.new do
      class << self
        def name
          "TestEvent"
        end
      end

      def initialize(data)
        @data = data
      end
    end

    HttpRequestTag = Class.new do
      class << self
        def name
          "HttpRequestTag"
        end
      end

      def initialize(http_method, http_status)
        @http_method = http_method
        @http_status = http_status
      end
    end

    test "#subscribe" do
      reporter = ActiveSupport::EventReporter.new
      reporter.subscribe(@subscriber)
      assert_equal([@subscriber], reporter.subscribers)
    end

    test "#subscribe raises ArgumentError when sink doesn't respond to emit" do
      invalid_subscriber = Object.new

      error = assert_raises(ArgumentError) do
        @reporter.subscribe(invalid_subscriber)
      end

      assert_equal "Event subscriber Object must respond to #emit", error.message
    end

    test "#notify with name" do
      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event")
      ]) do
        @reporter.notify(:test_event)
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
      def test_method
        @reporter.notify("test_event")
      end
      lineno = __LINE__ - 2

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "test_event", source_location: {
          filepath: __FILE__,
          lineno: lineno
        })
      ]) do
        test_method
      end
    end

    test "#notify with caller depth option" do
      def custom_log_abstraction(message)
        @reporter.notify(:custom_event, caller_depth: 2, message: message)
      end

      def another_test_method
        custom_log_abstraction("hello")
      end
      lineno = __LINE__ - 2

      assert_called_with(@subscriber, :emit, [
        event_matcher(
          name: "custom_event", payload: { message: "hello" }, source_location: {
          filepath: __FILE__,
          lineno: lineno
        })
      ]) do
        another_test_method
      end
    end

    test "#notify with event object" do
      event = TestEvent.new("value")

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "TestEvent", payload: event)
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
      previous_raise_on_error = @reporter.raise_on_error
      @reporter.raise_on_error = false

      event = TestEvent.new("value")

      _out, err = capture_io do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "TestEvent", payload: event)
        ]) do
          @reporter.notify(event, extra: "arg")
        rescue RailsStrictWarnings::WarningError => _e
          # Expected warning
        end
      end

      assert_match(/Rails.event.notify accepts either an event object, a payload hash, or keyword arguments/, err)

    ensure
      @reporter.raise_on_error = previous_raise_on_error
    end

    test "#notify warns about subscriber errors when raise_on_error is false" do
      previous_raise_on_error = @reporter.raise_on_error
      @reporter.raise_on_error = false

      error_subscriber = Class.new do
        def emit(event)
          raise StandardError.new("Uh oh!")
        end
      end

      @reporter.subscribe(error_subscriber.new)

      _out, err = capture_io do
        @reporter.notify(:test_event)
      rescue RailsStrictWarnings::WarningError => _e
        # Expected warning
      end

      assert_match(/Event reporter subscriber #{error_subscriber.name} raised an error on #emit: Uh oh!/, err)
    ensure
      @reporter.raise_on_error = previous_raise_on_error
    end

    test "#notify raises subscriber errors when raise_on_error is true" do
      error_subscriber = Class.new do
        def emit(event)
          raise StandardError.new("Uh oh!")
        end
      end

      @reporter.subscribe(error_subscriber.new)

      error = assert_raises(StandardError) do
        @reporter.notify(:test_event)
      end

      assert_equal("Uh oh!", error.message)
    end

    test "#with_debug" do
      @reporter.with_debug do
        assert_predicate @reporter, :debug_mode?
      end
      assert_not_predicate @reporter, :debug_mode?
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
      def custom_debug_log_abstraction(message)
        @reporter.debug(:custom_event, caller_depth: 2, message: message)
      end

      def test_method_debug
        custom_debug_log_abstraction("hello")
      end
      lineno = __LINE__ - 2

      assert_called_with(@subscriber, :emit, [
        event_matcher(name: "custom_event", payload: { message: "hello" }, source_location: {
          filepath: __FILE__,
          lineno: lineno
        })
      ]) do
        @reporter.with_debug { test_method_debug }
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
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { "HttpRequestTag": http_tag })
        ]) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end

    test "#tagged with mixed tags" do
      http_tag = HttpRequestTag.new("GET", 200)
      @reporter.tagged("foobar", http_tag, shop_id: 123) do
        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { "foobar": true, "HttpRequestTag": http_tag, shop_id: 123 })
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
      assert_equal(123, @reporter.context[:shop_id])
    end

    test "#set_context merges with existing context" do
      @reporter.set_context(shop_id: 123)
      @reporter.set_context(user_id: 456)
      assert_equal(123, @reporter.context[:shop_id])
      assert_equal(456, @reporter.context[:user_id])
    end

    test "#set_context overwrites existing keys" do
      @reporter.set_context(shop_id: 123)
      @reporter.set_context(shop_id: 456)
      assert_equal(456, @reporter.context[:shop_id])
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
        assert_equal(123, @reporter.context[:shop_id])

        assert_called_with(@subscriber, :emit, [
          event_matcher(name: "test_event", payload: { key: "value" }, tags: { request_id: "abc" }, context: { shop_id: 123 })
        ]) do
          @reporter.notify(:test_event, key: "value")
        end
      end
    end
  end

  class EncodersTest < ActiveSupport::TestCase
    TestEvent = Class.new do
      class << self
        def name
          "TestEvent"
        end
      end

      def initialize(data)
        @data = data
      end

      def to_h
        {
          data: @data
        }
      end
    end

    HttpRequestTag = Class.new do
      class << self
        def name
          "HttpRequestTag"
        end
      end

      def initialize(http_method, http_status)
        @http_method = http_method
        @http_status = http_status
      end

      def to_h
        {
          http_method: @http_method,
          http_status: @http_status
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

    test "looking up encoder by symbol" do
      assert_equal EventReporter::Encoders::JSON, EventReporter.encoder(:json)
      assert_equal EventReporter::Encoders::MessagePack, EventReporter.encoder(:msgpack)
    end

    test "looking up encoder by string" do
      assert_equal EventReporter::Encoders::JSON, EventReporter.encoder("json")
      assert_equal EventReporter::Encoders::MessagePack, EventReporter.encoder("msgpack")
    end

    test "looking up nonexistant encoder raises KeyError" do
      error = assert_raises(KeyError) do
        EventReporter.encoder(:unknown)
      end
      assert_equal "Unknown encoder format: :unknown. Available formats: json, msgpack", error.message
    end

    test "Base encoder raises NotImplementedError" do
      assert_raises(NotImplementedError) do
        EventReporter::Encoders::Base.encode(@event)
      end
    end

    test "JSON encoder encodes event to JSON" do
      json_string = EventReporter::Encoders::JSON.encode(@event)
      parsed = ::JSON.parse(json_string)

      assert_equal "test_event", parsed["name"]
      assert_equal({ "id" => 123, "message" => "hello" }, parsed["payload"])
      assert_equal({ "section" => "admin" }, parsed["tags"])
      assert_equal({ "user_id" => 456 }, parsed["context"])
      assert_equal 1738964843208679035, parsed["timestamp"]
      assert_equal({ "filepath" => "/path/to/file.rb", "lineno" => 42, "label" => "test_method" }, parsed["source_location"])
    end

    test "JSON encoder serializes event objects and object tags as hashes" do
      @event[:payload] = TestEvent.new("value")
      @event[:tags] = { "HttpRequestTag": HttpRequestTag.new("GET", 200) }
      json_string = EventReporter::Encoders::JSON.encode(@event)
      parsed = ::JSON.parse(json_string)

      assert_equal "value", parsed["payload"]["data"]
      assert_equal "GET", parsed["tags"]["HttpRequestTag"]["http_method"]
      assert_equal 200, parsed["tags"]["HttpRequestTag"]["http_status"]
    end

    test "MessagePack encoder encodes event to MessagePack" do
      begin
        require "msgpack"
      rescue LoadError
        skip "msgpack gem not available"
      end

      msgpack_data = EventReporter::Encoders::MessagePack.encode(@event)
      parsed = ::MessagePack.unpack(msgpack_data)

      assert_equal "test_event", parsed["name"]
      assert_equal({ "id" => 123, "message" => "hello" }, parsed["payload"])
      assert_equal({ "section" => "admin" }, parsed["tags"])
      assert_equal({ "user_id" => 456 }, parsed["context"])
      assert_equal 1738964843208679035, parsed["timestamp"]
      assert_equal({ "filepath" => "/path/to/file.rb", "lineno" => 42, "label" => "test_method" }, parsed["source_location"])
    end

    test "MessagePack encoder serializes event objects and object tags as hashes" do
      @event[:payload] = TestEvent.new("value")
      @event[:tags] = { "HttpRequestTag": HttpRequestTag.new("GET", 200) }
      msgpack_data = EventReporter::Encoders::MessagePack.encode(@event)
      parsed = ::MessagePack.unpack(msgpack_data)

      assert_equal "value", parsed["payload"]["data"]
      assert_equal "GET", parsed["tags"]["HttpRequestTag"]["http_method"]
      assert_equal 200, parsed["tags"]["HttpRequestTag"]["http_status"]
    end
  end
end
