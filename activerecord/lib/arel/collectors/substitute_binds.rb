# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class SubstituteBinds
      attr_accessor :preparable, :retryable

      # Binds that must be sent to the database as real parameters rather than
      # being substituted into the SQL string (see #add_bind_param).
      attr_reader :binds

      def initialize(quoter, delegate_collector)
        @quoter = quoter
        @delegate = delegate_collector
        @binds = []
      end

      def <<(str)
        delegate << str
        self
      end

      def add_bind(bind, &)
        bind = bind.value_for_database if bind.respond_to?(:value_for_database)
        self << quoter.quote(bind)
      end

      def add_binds(binds, proc_for_binds = nil, &)
        self << binds.map { |bind| quoter.quote(bind) }.join(", ")
      end

      # Keeps +bind+ as a real parameter instead of inlining its value into the
      # SQL. A placeholder is emitted through the delegate collector (e.g. +$1+)
      # and the bind is exposed via #binds so it can be sent over the wire. This
      # lets a single bind (such as an array for `col = ANY($1)`) avoid being
      # expanded into the SQL text even when prepared statements are disabled.
      def add_bind_param(bind, &block)
        @binds << bind
        delegate.add_bind(bind, &block)
        self
      end

      def value
        delegate.value
      end

      private
        attr_reader :quoter, :delegate
    end
  end
end
