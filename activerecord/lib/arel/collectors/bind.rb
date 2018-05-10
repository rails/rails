# frozen_string_literal: true

module Arel # :nodoc: all
  module Collectors
    class Bind
      def initialize
        @binds = []
      end

      def <<(_str)
        self
      end

      def add_bind(bind)
        @binds << bind
        self
      end

      def value
        @binds
      end
    end
  end
end
