# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class SubstituteBinds
      attr_accessor :preparable, :retryable

      def initialize(quoter, delegate_collector)
        @quoter = quoter
        @delegate = delegate_collector
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

      def value
        delegate.value
      end

      private
        attr_reader :quoter, :delegate
    end
  end
end
