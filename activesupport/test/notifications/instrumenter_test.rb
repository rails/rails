# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/notifications/instrumenter"

module ActiveSupport
  module Notifications
    class InstrumenterTest < ActiveSupport::TestCase
      class TestNotifier
        attr_reader :starts, :finishes

        def initialize
          @starts   = []
          @finishes = []
        end

        def start(*args);  @starts << args; end
        def finish(*args); @finishes << args; end
      end

      attr_reader :instrumenter, :notifier, :payload

      def setup
        super
        @notifier     = TestNotifier.new
        @instrumenter = Instrumenter.new @notifier
        @payload = { foo: Object.new }
      end

      def test_instrument
        called = false
        instrumenter.instrument("foo", payload) {
          called = true
        }

        assert called
      end

      def test_instrument_yields_the_payload_for_further_modification
        assert_equal 2, instrumenter.instrument("awesome") { |p| p[:result] = 1 + 1 }
        assert_equal 1, notifier.finishes.size
        name, _, payload = notifier.finishes.first
        assert_equal "awesome", name
        assert_equal Hash[result: 2], payload
      end

      def test_instrument_works_without_a_block
        instrumenter.instrument("no.block", payload)
        assert_equal 1, notifier.finishes.size
        assert_equal "no.block", notifier.finishes.first.first
      end

      def test_start
        instrumenter.start("foo", payload)
        assert_equal [["foo", instrumenter.id, payload]], notifier.starts
        assert_empty notifier.finishes
      end

      def test_finish
        instrumenter.finish("foo", payload)
        assert_equal [["foo", instrumenter.id, payload]], notifier.finishes
        assert_empty notifier.starts
      end

      def test_record
        called = false
        event = instrumenter.new_event("foo", payload)
        event.record {
          called = true
        }

        assert called
      end

      def test_record_yields_the_payload_for_further_modification
        event = instrumenter.new_event("awesome")
        event.record { |p| p[:result] = 1 + 1 }
        assert_equal 2, event.payload[:result]

        assert_equal "awesome", event.name
        assert_equal Hash[result: 2], event.payload
        assert_equal instrumenter.id, event.transaction_id
        assert_not_nil event.time
        assert_not_nil event.end
      end

      def test_record_works_without_a_block
        event = instrumenter.new_event("no.block", payload)
        event.record

        assert_equal "no.block", event.name
        assert_equal payload, event.payload
        assert_equal instrumenter.id, event.transaction_id
        assert_not_nil event.time
        assert_not_nil event.end
      end

      def test_record_with_exception
        event = instrumenter.new_event("crash", payload)
        assert_raises RuntimeError do
          event.record { raise "Oopsies" }
        end
        assert_equal "Oopsies", event.payload[:exception_object].message
      end
    end
  end
end
