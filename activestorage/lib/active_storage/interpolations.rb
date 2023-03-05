# frozen_string_literal: true

module ActiveStorage
  module Interpolations
    extend self
    MINIMUM_TOKEN_LENGTH = 28

    class << self
      def []=(name, block)
        define_method(name, &block)
      end

      def all
        self.instance_methods(false).sort!
      end

      def any?
        self.interpolators_cache.any?
      end

      def interpolate(pattern, *args)
        self.interpolators_cache.each do |method, token|
          pattern.gsub!(token) { send(method, *args) } if pattern.include?(token)
        end
        result
      end

      def interpolators_cache
        @interpolators_cache ||= all.reverse!.map! { |method| [method, ":#{method}"] }
      end
    end
  end
end
