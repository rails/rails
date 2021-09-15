# frozen_string_literal: true

require "active_support/inflector"

module Rails
  module Autoloaders
    module Inflector # :nodoc:
      # Concurrent::Map is not needed. This is a private class, and overrides
      # must be defined while the application boots.
      @overrides = {}

      def self.camelize(basename, _abspath)
        @overrides[basename] || basename.camelize
      end

      def self.inflect(overrides)
        @overrides.merge!(overrides)
      end
    end
  end
end
