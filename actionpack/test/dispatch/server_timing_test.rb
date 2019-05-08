# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  class ServerTimingTest < ActiveSupport::TestCase
    def teardown
      ServerTiming.clear_timings!
    end

    def test_to_header_with_only_a_key
      ServerTiming.add_timing(key: :test)
      assert_equal "test", ServerTiming.to_header
    end

    def test_to_header_with_key_duration_and_description
      ServerTiming.add_timing(key: :test, dur: 3, desc: "desc")
      assert_equal 'test;desc="desc";dur=3', ServerTiming.to_header
    end

    def test_to_header_with_key_and_duration
      ServerTiming.add_timing(key: :test, dur: 3)
      assert_equal "test;dur=3", ServerTiming.to_header
    end

    def test_to_header_with_key_and_description
      ServerTiming.add_timing(key: :test, desc: "test")
      assert_equal 'test;desc="test"', ServerTiming.to_header
    end

    def test_to_header_with_multiple_timings
      expected_header = 'test;desc="test";dur=1, test2;desc="test2";dur=2'
      ServerTiming.add_timing(key: :test,  desc: "test", dur: 1)
      ServerTiming.add_timing(key: :test2, desc: "test2", dur: 2)
      assert_equal expected_header, ServerTiming.to_header
    end

    def test_measure
      ServerTiming.measure(:test, desc: "desc") do
        "do a thing"
      end

      assert_not_nil ServerTiming.timings[:test]
      assert_not_nil ServerTiming.timings[:test][:dur]
      assert_equal "desc", ServerTiming.timings[:test][:desc]
    end

    def test_middleware_adds_server_timing_headers
      app = -> env do
        ServerTiming.add_timing(key: :test, dur: 1, desc: "desc")

        [ 200, {}, [""]]
      end

      response = ServerTiming.new(app).call({})

      assert_equal 'test;desc="desc";dur=1', response[1]["Server-Timing"]
    end

    def test_timings_are_cleared_even_if_there_is_an_exception_during_the_request
      app = -> env do
        ServerTiming.add_timing(key: :test, dur: 1, desc: "desc")
        raise
      end

      assert_raises do
        ServertTiming.new(app).call({})
      end

      assert_empty ServerTiming.timings
    end

    def test_subscribes_to_all_events_when_subscribe_all_is_set_to_true
      app = -> env do
        ActiveSupport::Notifications.instrument("my_test") { "do a thing" }
        ActiveSupport::Notifications.instrument("my_other_test") { "do another thing" }

        [ 200, {}, [""]]
      end

      response = ServerTiming.new(app, all_events: true).call({})

      assert_match(/my_test;dur=.*, my_other_test;dur=.*/, response[1]["Server-Timing"])
    end

    def test_subscribe_to_custom_events
      app = -> env do
        ActiveSupport::Notifications.instrument("custom_event") { "do a thing" }
        ActiveSupport::Notifications.instrument("do_not_susbcribe") { "do another thing" }

        [ 200, {}, [""]]
      end

      response = ServerTiming.new(app, events: ["custom_event"]).call({})

      assert_match(/custom_event;dur=.*/, response[1]["Server-Timing"])
    end

    def test_extract_duration_from_custom_keys_for_events
      app = -> env do
        ActiveSupport::Notifications.instrument("event_with_keys", foo: 1, bar: 2)

        [ 200, {}, [""]]
      end

      response = ServerTiming.new(app, events: [{ "event_with_keys" => [:foo, :bar] }]).call({})

      assert_equal "foo;dur=1, bar;dur=2", response[1]["Server-Timing"]
    end

    def test_providing_key_and_description_through_server_timing_key_in_event_payload
      app = -> env do
        ActiveSupport::Notifications.instrument("test_event", server_timing: { key: "my_key", desc: "my_desc" }) do
          "do the thing"
        end

        [200, {}, [""]]
      end

      response = ServerTiming.new(app, events: [ "test_event" ]).call({})

      assert_match(/my_key;desc="my_desc";dur=.*/, response[1]["Server-Timing"])
    end

    def test_measure_returns_correct_headers
      app = -> env do
        ActionDispatch::ServerTiming.measure("measure_test") do
          "do the thing"
        end

        [200, {}, [""]]
      end

      response = ServerTiming.new(app, all_events: false).call({})

      assert_match(/test;dur=.*/, response[1]["Server-Timing"])
    end
  end
end
