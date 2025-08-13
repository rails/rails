# typed: true
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
        assert_match(/name: user\.created/, e.message)
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
    end
  end
end
