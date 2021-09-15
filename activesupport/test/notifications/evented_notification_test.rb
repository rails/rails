# frozen_string_literal: true

require_relative "../abstract_unit"

module ActiveSupport
  module Notifications
    class EventedTest < ActiveSupport::TestCase
      class Listener
        attr_reader :events

        def initialize
          @events = []
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

      class ListenerWithFinishStateSupport < Listener
        def start(name, id, payload)
          super

          [:state, name, id, payload] # state
        end

        def finish_with_state(state, name, id, payload)
          @events << [:finish_with_state, state, name, id, payload]
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

      def test_evented_listener_with_state_preferenced_ordered
        notifier = Fanout.new
        listener = ListenerWithFinishStateSupport.new
        notifier.subscribe nil, listener
        state1 = notifier.start  "hello", 1, {}
        state2 = notifier.start  "world", 1, {}
        notifier.finish "world", 1, {}, state2
        notifier.finish "hello", 1, {}, state1

        assert_equal 4, listener.events.length
        assert_equal [
          [:start,  "hello", 1, {}],
          [:start,  "world", 1, {}],
          [:finish_with_state,  [:state, "world", 1, {}], "world", 1, {}],
          [:finish_with_state,  [:state, "hello", 1, {}], "hello", 1, {}],
        ], listener.events
      end

      def test_evented_listener_with_state_preferenced_ordered_implicit_stack
        notifier = Fanout.new
        listener = ListenerWithFinishStateSupport.new
        notifier.subscribe nil, listener
        notifier.start  "hello", 1, {}
        notifier.start  "world", 1, {}
        notifier.finish "world", 1, {} # without passing in state, should rely on stack order
        notifier.finish "hello", 1, {}

        assert_equal 4, listener.events.length
        assert_equal [
          [:start,  "hello", 1, {}],
          [:start,  "world", 1, {}],
          [:finish_with_state,  [:state, "world", 1, {}], "world", 1, {}],
          [:finish_with_state,  [:state, "hello", 1, {}], "hello", 1, {}],
        ], listener.events
      end

      def test_evented_listener_with_state_preferenced_unordered
        notifier = Fanout.new
        listener = ListenerWithFinishStateSupport.new
        notifier.subscribe nil, listener
        state1 = notifier.start  "hello", 1, {}
        state2 = notifier.start  "world", 1, {}
        notifier.finish "hello", 1, {}, state1
        notifier.finish "world", 1, {}, state2

        assert_equal 4, listener.events.length
        assert_equal [
          [:start,  "hello", 1, {}],
          [:start,  "world", 1, {}],
          [:finish_with_state,  [:state, "hello", 1, {}], "hello", 1, {}],
          [:finish_with_state,  [:state, "world", 1, {}], "world", 1, {}],
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

      def test_listen_to_regexp
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe(/[a-z]*.world/, listener)
        notifier.start("hi.world", 1, {})
        notifier.finish("hi.world", 2, {})
        notifier.start("hello.world", 1, {})
        notifier.finish("hello.world", 2, {})

        assert_equal [
          [:start, "hi.world", 1, {}],
          [:finish, "hi.world", 2, {}],
          [:start, "hello.world", 1, {}],
          [:finish, "hello.world", 2, {}]
        ], listener.events
      end

      def test_listen_to_regexp_with_exclusions
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe(/[a-z]*.world/, listener)
        notifier.unsubscribe("hi.world")
        notifier.start("hi.world", 1, {})
        notifier.finish("hi.world", 2, {})
        notifier.start("hello.world", 1, {})
        notifier.finish("hello.world", 2, {})

        assert_equal [
          [:start, "hello.world", 1, {}],
          [:finish, "hello.world", 2, {}]
        ], listener.events
      end
    end
  end
end
