require "abstract_unit"

module ActiveSupport
  module Notifications
    class EventedTest < ActiveSupport::TestCase
      class Listener
        attr_reader :events

        def initialize
          @events   = []
        end

        def start(name, id, payload)
          @events << [:start, name, id, payload]
        end

        def finish(name, id, payload)
          @events << [:finish, name, id, payload]
        end
      end

      class ListenerWithTimedSupport < Listener
        def call(name, start, finish, id, payload)
          @events << [:call, name, start, finish, id, payload]
        end
      end

      def test_evented_listener
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe "hi", listener
        notifier.start  "hi", 1, {}
        notifier.start  "hi", 2, {}
        notifier.finish "hi", 2, {}
        notifier.finish "hi", 1, {}

        assert_equal 4, listener.events.length
        assert_equal [
          [:start, "hi", 1, {}],
          [:start, "hi", 2, {}],
          [:finish, "hi", 2, {}],
          [:finish, "hi", 1, {}],
        ], listener.events
      end

      def test_evented_listener_no_events
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe "hi", listener
        notifier.start  "world", 1, {}
        assert_equal 0, listener.events.length
      end

      def test_listen_to_everything
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe nil, listener
        notifier.start  "hello", 1, {}
        notifier.start  "world", 1, {}
        notifier.finish  "world", 1, {}
        notifier.finish  "hello", 1, {}

        assert_equal 4, listener.events.length
        assert_equal [
          [:start,  "hello", 1, {}],
          [:start,  "world", 1, {}],
          [:finish,  "world", 1, {}],
          [:finish,  "hello", 1, {}],
        ], listener.events
      end

      def test_evented_listener_priority
        notifier = Fanout.new
        listener = ListenerWithTimedSupport.new
        notifier.subscribe "hi", listener

        notifier.start "hi", 1, {}
        notifier.finish "hi", 1, {}

        assert_equal [
          [:start, "hi", 1, {}],
          [:finish, "hi", 1, {}]
        ], listener.events
      end
    end
  end
end
