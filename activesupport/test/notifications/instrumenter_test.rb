# frozen_string_literal: true

require "abstract_unit"
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

      def test_start
        instrumenter.start("foo", payload)
        assert_equal [["foo", instrumenter.id, payload]], notifier.starts
        assert_predicate notifier.finishes, :empty?
      end

      def test_finish
        instrumenter.finish("foo", payload)
        assert_equal [["foo", instrumenter.id, payload]], notifier.finishes
        assert_predicate notifier.starts, :empty?
      end
    end
  end
end
