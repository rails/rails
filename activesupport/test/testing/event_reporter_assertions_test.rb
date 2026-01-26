# frozen_string_literal: true

require "active_support/test_case"

module ActiveSupport
  module Testing
    class EventReporterAssertionsTest < ActiveSupport::TestCase
      setup do
        @reporter = ActiveSupport.event_reporter
      end

      test "#assert_event_reported" do
        assert_event_reported("user.created") do
          @reporter.notify("user.created", { id: 123, name: "John Doe" })
        end
      end

      test "#assert_event_reported with payload" do
        assert_event_reported("user.created", payload: { id: 123, name: "John Doe" }) do
          @reporter.notify("user.created", { id: 123, name: "John Doe" })
        end
      end

      test "#assert_event_reported with tags" do
        assert_event_reported("user.created", tags: { graphql: true }) do
          @reporter.tagged(:graphql) do
            @reporter.notify("user.created", { id: 123, name: "John Doe" })
          end
        end
      end

      test "#assert_event_reported partial matching" do
        assert_event_reported("user.created", payload: { id: 123 }, tags: { foo: :bar }) do
          @reporter.tagged(foo: :bar, baz: :qux) do
            @reporter.notify("user.created", { id: 123, name: "John Doe" })
          end
        end
      end

      test "#assert_event_reported with regex payload" do
        assert_event_reported("user.created", payload: { id: /[0-9]+/ }) do
          @reporter.notify("user.created", { id: 123, name: "John Doe" })
        end
      end

      test "#assert_event_reported with regex tags" do
        assert_event_reported("user.created", tags: { foo: /bar/ }) do
          @reporter.tagged(foo: :bar, baz: :qux) do
            @reporter.notify("user.created")
          end
        end
      end

      test "#assert_no_event_reported" do
        assert_no_event_reported do
          # No events are reported here
        end
      end

      test "#assert_no_event_reported with provided name" do
        assert_no_event_reported("user.created") do
          @reporter.notify("another.event")
        end
      end

      test "#assert_no_event_reported with payload" do
        assert_no_event_reported("user.created", payload: { id: 123, name: "Sazz Pataki" }) do
          @reporter.notify("user.created", { id: 123, name: "Mabel Mora" })
        end

        assert_no_event_reported("user.created", payload: { name: "Sazz Pataki" }) do
          @reporter.notify("user.created")
        end
      end

      test "#assert_no_event_reported with tags" do
        assert_no_event_reported("user.created", tags: { api: true, zip_code: 10003 }) do
          @reporter.tagged(api: false, zip_code: 10003) do
            @reporter.notify("user.created")
          end
        end

        assert_no_event_reported("user.created", tags: { api: true }) do
          @reporter.notify("user.created")
        end
      end

      test "#assert_event_reported fails when event is not reported" do
        e = assert_raises(Minitest::Assertion) do
          assert_event_reported("user.created") do
            # No events are reported here
          end
        end

        assert_equal "Expected an event to be reported, but there were no events reported.", e.message
      end

      test "#assert_event_reported fails when different event is reported" do
        e = assert_raises(Minitest::Assertion) do
          assert_event_reported("user.created", payload: { id: 123 }) do
            @reporter.notify("another.event", { id: 123, name: "John Doe" })
          end
        end

        assert_match(/Expected an event to be reported matching:/, e.message)
        assert_match(/name: "user\.created"/, e.message)
        assert_match(/but none of the 1 reported events matched:/, e.message)
        assert_match(/another\.event/, e.message)
      end

      test "#assert_no_event_reported fails when event is reported" do
        payload = { id: 123, name: "John Doe" }
        e = assert_raises(Minitest::Assertion) do
          assert_no_event_reported("user.created") do
            @reporter.notify("user.created", payload)
          end
        end

        assert_match(/Expected no 'user\.created' event to be reported, but found:/, e.message)
        assert_match(/user\.created/, e.message)
      end

      test "assert_events_reported" do
        assert_events_reported([
          { name: "user.created" },
          { name: "email.sent" }
        ]) do
          @reporter.notify("user.created", { id: 123 })
          @reporter.notify("email.sent", { to: "user@example.com" })
        end
      end

      test "assert_events_reported is order agnostic" do
        assert_events_reported([
          { name: "user.created", payload: { id: 123 } },
          { name: "email.sent" }
        ]) do
          @reporter.notify("email.sent", { to: "user@example.com" })
          @reporter.notify("user.created", { id: 123, name: "John" })
        end
      end

      test "assert_events_reported ignores extra events" do
        assert_events_reported([
          { name: "user.created", payload: { id: 123 } }
        ]) do
          @reporter.notify("extra_event_1")
          @reporter.notify("user.created", { id: 123, name: "John" })
          @reporter.notify("extra_event_2")
          @reporter.notify("extra_event_3")
        end
      end

      test "assert_events_reported works with empty expected array" do
        assert_events_reported([]) do
          @reporter.notify("some.event")
        end
      end

      test "assert_events_reported fails when one event missing" do
        e = assert_raises(Minitest::Assertion) do
          assert_events_reported([
            { name: "user.created" },
            { name: "email.sent" }
          ]) do
            @reporter.notify("user.created", { id: 123 })
            @reporter.notify("other.event")
          end
        end

        assert_match(/Expected an event to be reported matching:/, e.message)
        assert_match(/name: "email.sent"/, e.message)
        assert_match(/but none of the .* reported events matched:/, e.message)
      end

      test "assert_events_reported fails when no events reported" do
        e = assert_raises(Minitest::Assertion) do
          assert_events_reported([
            { name: "user.created" },
            { name: "email.sent" }
          ]) do
            # No events reported
          end
        end

        assert_equal "Expected 2 events to be reported, but there were no events reported.", e.message
      end

      test "assert_events_reported fails when expecting duplicate events but only one reported" do
        e = assert_raises(Minitest::Assertion) do
          assert_events_reported([
            { name: "user.created" },
            { name: "user.created" }  # Expecting 2 identical events
          ]) do
            @reporter.notify("user.created")
          end
        end

        assert_match(/Expected an event to be reported matching:/, e.message)
        assert_match(/name: "user.created"/, e.message)
        assert_match(/but none of the 1 reported events matched:/, e.message)
      end

      test "assert_events_reported passes when expecting duplicate events and both are reported" do
        assert_events_reported([
          { name: "user.created", payload: { id: 123 } },
          { name: "user.created", payload: { id: 123 } }
        ]) do
          @reporter.notify("user.created", { id: 123 })
          @reporter.notify("user.created", { id: 123 })
        end
      end
    end
  end
end
