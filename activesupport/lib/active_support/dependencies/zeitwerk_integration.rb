# frozen_string_literal: true

require "set"
require "zeitwerk"

module ActiveSupport
  module Dependencies
    module ZeitwerkIntegration # :nodoc: all
      module Decorations
        def clear
          Dependencies.unload_interlock do
            _autoloaded_tracked_classes.clear
            Rails.autoloaders.main.reload
          rescue Zeitwerk::ReloadingDisabledError
            raise "reloading is disabled because config.cache_classes is true"
          end
        end
      end

      module Inflector
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

      def self.take_over
        Dependencies.singleton_class.prepend(Decorations)
      end
    end
  end
end
