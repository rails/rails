# frozen_string_literal: true

module Arel
  module Collectors
    class Bind
      def initialize
        @binds = []
      end

      def << str
        self
      end

      def add_bind bind
        @binds << bind
        self
      end

      def value
        @binds
      end
    end
  end
end
