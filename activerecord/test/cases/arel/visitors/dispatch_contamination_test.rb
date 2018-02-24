# frozen_string_literal: true
require_relative '../helper'
require 'concurrent'

module Arel
  module Visitors
    class DummyVisitor < Visitor
      def initialize
        super
        @barrier = Concurrent::CyclicBarrier.new(2)
      end

      def visit_Arel_Visitors_DummySuperNode node
        42
      end

      # This is terrible, but it's the only way to reliably reproduce
      # the possible race where two threads attempt to correct the
      # dispatch hash at the same time.
      def send *args
        super
      rescue
        # Both threads try (and fail) to dispatch to the subclass's name
        @barrier.wait
        raise
      ensure
        # Then one thread successfully completes (updating the dispatch
        # table in the process) before the other finishes raising its
        # exception.
        Thread.current[:delay].wait if Thread.current[:delay]
      end
    end

    class DummySuperNode
    end

    class DummySubNode < DummySuperNode
    end

    class DispatchContaminationTest < Arel::Spec
      before do
        @connection = Table.engine.connection
        @table = Table.new(:users)
      end

      it 'dispatches properly after failing upwards' do
        node = Nodes::Union.new(Nodes::True.new, Nodes::False.new)
        assert_equal "( TRUE UNION FALSE )", node.to_sql

        node.first # from Nodes::Node's Enumerable mixin

        assert_equal "( TRUE UNION FALSE )", node.to_sql
      end

      it 'is threadsafe when implementing superclass fallback' do
        visitor = DummyVisitor.new
        main_thread_finished = Concurrent::Event.new

        racing_thread = Thread.new do
          Thread.current[:delay] = main_thread_finished
          visitor.accept DummySubNode.new
        end

        assert_equal 42, visitor.accept(DummySubNode.new)
        main_thread_finished.set

        assert_equal 42, racing_thread.value
      end
    end
  end
end

