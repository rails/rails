# frozen_string_literal: true

require_relative "../abstract_unit"

module ActiveSupport
  module Notifications
    class EventedTest < ActiveSupport::TestCase
      # we expect all exception types to be handled, so test with the most basic type
      class BadListenerException < Exception; end

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

      class BadStartListener < Listener
        def start(name, id, payload)
          raise BadListenerException
        end

        def finish(name, id, payload)
        end
      end

      class BadFinishListener < Listener
        def start(name, id, payload)
        end

        def finish(name, id, payload)
          raise BadListenerException
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

      def test_listen_start_multiple_exception_consistency
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe nil, BadStartListener.new
        notifier.subscribe nil, BadStartListener.new
        notifier.subscribe nil, listener

        error = assert_raises InstrumentationSubscriberError do
          notifier.start  "hello", 1, {}
        end
        assert_instance_of BadListenerException, error.cause

        error = assert_raises InstrumentationSubscriberError do
          notifier.start  "world", 1, {}
        end
        assert_instance_of BadListenerException, error.cause

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

      def test_listen_finish_multiple_exception_consistency
        notifier = Fanout.new
        listener = Listener.new
        notifier.subscribe nil, BadFinishListener.new
        notifier.subscribe nil, BadFinishListener.new
        notifier.subscribe(nil) { |*args| raise "foo" }
        notifier.subscribe(nil) { |obj| raise "foo" }
        notifier.subscribe(nil, monotonic: true) { |obj| raise "foo" }
        notifier.subscribe nil, listener

        notifier.start  "hello", 1, {}
        notifier.start  "world", 1, {}
        error = assert_raises InstrumentationSubscriberError do
          notifier.finish  "world", 1, {}
        end
        assert_equal 5, error.exceptions.count
        assert_instance_of BadListenerException, error.cause

        error = assert_raises InstrumentationSubscriberError do
          notifier.finish  "hello", 1, {}
        end
        assert_equal 5, error.exceptions.count
        assert_instance_of BadListenerException, error.cause

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
